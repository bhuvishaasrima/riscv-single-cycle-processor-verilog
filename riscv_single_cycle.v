// ============================================================
// RISC-V Single-Cycle Processor
// Supported Instructions:
// ADD, SUB, AND, OR, LW, SW, BEQ
// ============================================================


// ============================================================
// Program Counter
// ============================================================

module Program_Counter(clk, reset, PC_in, PC_out);

input clk, reset;
input [31:0] PC_in;
output reg [31:0] PC_out;

always @(posedge clk or posedge reset)
begin
    if(reset)
        PC_out <= 32'b0;
    else
        PC_out <= PC_in;
end

endmodule


// ============================================================
// PC + 4
// ============================================================

module PCplus4(fromPC, NextoPC);

input [31:0] fromPC;
output [31:0] NextoPC;

assign NextoPC = fromPC + 32'd4;

endmodule


// ============================================================
// Instruction Memory
//
// 64 words x 32 bits
//
// Combinational read for true single-cycle operation.
//
// Test program:
//
// Address  Instruction
// 0        LW  x1, 0(x0)
// 4        LW  x2, 4(x0)
// 8        ADD x3, x1, x2
// 12       SUB x4, x2, x1
// 16       AND x5, x1, x2
// 20       OR  x6, x1, x2
// 24       SW  x3, 8(x0)
// 28       BEQ x3, x6, +8
// 32       SW  x4, 12(x0)   <-- skipped when BEQ is taken
// 36       SW  x6, 16(x0)
// ============================================================

module Instruction_Memory(clk, reset, read_address, instruction_out);

input clk, reset;
input [31:0] read_address;
output [31:0] instruction_out;

reg [31:0] I_Mem[63:0];

integer k;


// ------------------------------------------------------------
// Initialize instruction memory
// ------------------------------------------------------------

always @(posedge reset)
begin
    for(k = 0; k < 64; k = k + 1)
    begin
        I_Mem[k] <= 32'b0;
    end

    // --------------------------------------------------------
    // Test program
    // --------------------------------------------------------

    // LW x1, 0(x0)
    I_Mem[0] <= 32'h00002083;

    // LW x2, 4(x0)
    I_Mem[1] <= 32'h00402103;

    // ADD x3, x1, x2
    I_Mem[2] <= 32'h002081B3;

    // SUB x4, x2, x1
    I_Mem[3] <= 32'h40110233;

    // AND x5, x1, x2
    I_Mem[4] <= 32'h0020F2B3;

    // OR x6, x1, x2
    I_Mem[5] <= 32'h0020E333;

    // SW x3, 8(x0)
    I_Mem[6] <= 32'h00302423;

    // BEQ x3, x6, +8
    I_Mem[7] <= 32'h00618463;

    // SW x4, 12(x0)
    // This instruction should be SKIPPED
    I_Mem[8] <= 32'h00402623;

    // SW x6, 16(x0)
    I_Mem[9] <= 32'h00602823;
end


// ------------------------------------------------------------
// Combinational instruction read
// ------------------------------------------------------------

assign instruction_out = I_Mem[read_address[7:2]];

endmodule


// ============================================================
// Register File
// ============================================================

module Reg_File(
    clk,
    reset,
    RegWrite,
    Rs1,
    Rs2,
    Rd,
    Write_data,
    read_data1,
    read_data2
);

input clk, reset, RegWrite;
input [4:0] Rs1, Rs2, Rd;
input [31:0] Write_data;

output [31:0] read_data1, read_data2;

integer k;

reg [31:0] Registers[31:0];


// ------------------------------------------------------------
// Register write
// ------------------------------------------------------------

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        for(k = 0; k < 32; k = k + 1)
        begin
            Registers[k] <= 32'b0;
        end
    end
    else if(RegWrite && (Rd != 5'b00000))
    begin
        Registers[Rd] <= Write_data;
    end
end


// ------------------------------------------------------------
// Register reads
// x0 always reads as zero
// ------------------------------------------------------------

assign read_data1 =
    (Rs1 == 5'b00000) ? 32'b0 : Registers[Rs1];

assign read_data2 =
    (Rs2 == 5'b00000) ? 32'b0 : Registers[Rs2];

endmodule


// ============================================================
// Immediate Generator
// ============================================================

module ImmGen(Opcode, instruction, ImmExt);

input [6:0] Opcode;
input [31:0] instruction;

output reg [31:0] ImmExt;

always @(*)
begin

    ImmExt = 32'b0;

    case(Opcode)

        // ----------------------------------------------------
        // I-type: LW
        // ----------------------------------------------------

        7'b0000011:
            ImmExt = {
                {20{instruction[31]}},
                instruction[31:20]
            };


        // ----------------------------------------------------
        // S-type: SW
        // ----------------------------------------------------

        7'b0100011:
            ImmExt = {
                {20{instruction[31]}},
                instruction[31:25],
                instruction[11:7]
            };


        // ----------------------------------------------------
        // B-type: BEQ
        //
        // imm[12]   = instruction[31]
        // imm[11]   = instruction[7]
        // imm[10:5] = instruction[30:25]
        // imm[4:1]  = instruction[11:8]
        // imm[0]    = 0
        // ----------------------------------------------------

        7'b1100011:
            ImmExt = {
                {19{instruction[31]}},
                instruction[31],
                instruction[7],
                instruction[30:25],
                instruction[11:8],
                1'b0
            };


        default:
            ImmExt = 32'b0;

    endcase
end

endmodule


// ============================================================
// Control Unit
// ============================================================

module Control_Unit(
    instruction,
    Branch,
    MemRead,
    MemtoReg,
    ALUOp,
    MemWrite,
    ALUSrc,
    RegWrite
);

input [6:0] instruction;

output reg Branch;
output reg MemRead;
output reg MemtoReg;
output reg MemWrite;
output reg ALUSrc;
output reg RegWrite;

output reg [1:0] ALUOp;


always @(*)
begin

    // --------------------------------------------------------
    // Safe defaults
    // --------------------------------------------------------

    Branch   = 1'b0;
    MemRead  = 1'b0;
    MemtoReg = 1'b0;
    MemWrite = 1'b0;
    ALUSrc   = 1'b0;
    RegWrite = 1'b0;
    ALUOp    = 2'b00;


    case(instruction)

        // ----------------------------------------------------
        // R-type
        // ADD, SUB, AND, OR
        // ----------------------------------------------------

        7'b0110011:

            {ALUSrc, MemtoReg, RegWrite,
             MemRead, MemWrite, Branch, ALUOp}

            = 8'b001000_10;


        // ----------------------------------------------------
        // LW
        // ----------------------------------------------------

        7'b0000011:

            {ALUSrc, MemtoReg, RegWrite,
             MemRead, MemWrite, Branch, ALUOp}

            = 8'b111100_00;


        // ----------------------------------------------------
        // SW
        // ----------------------------------------------------

        7'b0100011:

            {ALUSrc, MemtoReg, RegWrite,
             MemRead, MemWrite, Branch, ALUOp}

            = 8'b100010_00;


        // ----------------------------------------------------
        // BEQ
        // ----------------------------------------------------

        7'b1100011:

            {ALUSrc, MemtoReg, RegWrite,
             MemRead, MemWrite, Branch, ALUOp}

            = 8'b000001_01;


        default:

            {ALUSrc, MemtoReg, RegWrite,
             MemRead, MemWrite, Branch, ALUOp}

            = 8'b000000_00;

    endcase

end

endmodule


// ============================================================
// ALU
// ============================================================

module ALU_unit(
    A,
    B,
    Control_in,
    ALU_Result,
    zero
);

input [31:0] A, B;
input [3:0] Control_in;

output reg [31:0] ALU_Result;
output reg zero;


always @(*)
begin

    ALU_Result = 32'b0;
    zero = 1'b0;


    case(Control_in)

        // ----------------------------------------------------
        // AND
        // ----------------------------------------------------

        4'b0000:
            ALU_Result = A & B;


        // ----------------------------------------------------
        // OR
        // ----------------------------------------------------

        4'b0001:
            ALU_Result = A | B;


        // ----------------------------------------------------
        // ADD
        // ----------------------------------------------------

        4'b0010:
            ALU_Result = A + B;


        // ----------------------------------------------------
        // SUB
        // ----------------------------------------------------

        4'b0110:
            ALU_Result = A - B;


        default:
            ALU_Result = 32'b0;

    endcase


    // --------------------------------------------------------
    // Zero flag
    // --------------------------------------------------------

    if(ALU_Result == 32'b0)
        zero = 1'b1;
    else
        zero = 1'b0;

end

endmodule


// ============================================================
// ALU Control
// ============================================================

module ALU_Control(
    ALUOp,
    fun7,
    fun3,
    Control_out
);

input fun7;
input [2:0] fun3;
input [1:0] ALUOp;

output reg [3:0] Control_out;


always @(*)
begin

    // Default = ADD
    Control_out = 4'b0010;


    case(ALUOp)

        // ----------------------------------------------------
        // LW / SW
        // Address = register + immediate
        // ----------------------------------------------------

        2'b00:
            Control_out = 4'b0010;


        // ----------------------------------------------------
        // BEQ
        // Compare by subtraction
        // ----------------------------------------------------

        2'b01:
            Control_out = 4'b0110;


        // ----------------------------------------------------
        // R-type
        // ----------------------------------------------------

        2'b10:
        begin

            case({fun7, fun3})

                // ADD
                4'b0_000:
                    Control_out = 4'b0010;

                // SUB
                4'b1_000:
                    Control_out = 4'b0110;

                // AND
                4'b0_111:
                    Control_out = 4'b0000;

                // OR
                4'b0_110:
                    Control_out = 4'b0001;

                default:
                    Control_out = 4'b0010;

            endcase

        end


        default:
            Control_out = 4'b0010;

    endcase

end

endmodule


// ============================================================
// Data Memory
//
// 64 words x 32 bits
//
// Initial values:
//
// D_Memory[0] = 5
// D_Memory[1] = 10
//
// These are loaded by LW instructions.
//
// Expected results:
//
// x1 = 5
// x2 = 10
// x3 = 15
// x4 = 5
// x5 = 0
// x6 = 15
//
// D_Memory[2] = 15
// D_Memory[3] remains 0 because BEQ skips SW
// D_Memory[4] = 15
// ============================================================

module Data_Memory(
    clk,
    reset,
    MemWrite,
    MemRead,
    read_address,
    Write_data,
    MemData_out
);

input clk, reset;
input MemWrite, MemRead;

input [31:0] read_address;
input [31:0] Write_data;

output [31:0] MemData_out;

integer k;

reg [31:0] D_Memory[63:0];


// ------------------------------------------------------------
// Memory reset / write
// ------------------------------------------------------------

always @(posedge clk or posedge reset)
begin

    if(reset)
    begin

        for(k = 0; k < 64; k = k + 1)
        begin
            D_Memory[k] <= 32'b0;
        end

        // ----------------------------------------------------
        // Test data
        // ----------------------------------------------------

        D_Memory[0] <= 32'd5;
        D_Memory[1] <= 32'd10;

    end

    else if(MemWrite)
    begin
        D_Memory[read_address[7:2]] <= Write_data;
    end

end


// ------------------------------------------------------------
// Combinational data-memory read
// ------------------------------------------------------------

assign MemData_out =
    (MemRead) ?
    D_Memory[read_address[7:2]] :
    32'b0;

endmodule


// ============================================================
// Multiplexer 1
//
// ALUSrc = 0 -> Register data
// ALUSrc = 1 -> Immediate
// ============================================================

module Mux1(sel1, A1, B1, Mux1_out);

input sel1;

input [31:0] A1;
input [31:0] B1;

output [31:0] Mux1_out;

assign Mux1_out =
    (sel1 == 1'b0) ? A1 : B1;

endmodule


// ============================================================
// Multiplexer 2
//
// sel2 = 0 -> PC + 4
// sel2 = 1 -> Branch target
// ============================================================

module Mux2(sel2, A2, B2, Mux2_out);

input sel2;

input [31:0] A2;
input [31:0] B2;

output [31:0] Mux2_out;

assign Mux2_out =
    (sel2 == 1'b0) ? A2 : B2;

endmodule


// ============================================================
// Multiplexer 3
//
// MemtoReg = 0 -> ALU result
// MemtoReg = 1 -> Data memory
// ============================================================

module Mux3(sel3, A3, B3, Mux3_out);

input sel3;

input [31:0] A3;
input [31:0] B3;

output [31:0] Mux3_out;

assign Mux3_out =
    (sel3 == 1'b0) ? A3 : B3;

endmodule


// ============================================================
// AND Logic
//
// Branch taken = Branch AND Zero
// ============================================================

module AND_logic(branch, zero, and_out);

input branch;
input zero;

output and_out;

assign and_out = branch & zero;

endmodule


// ============================================================
// Adder
//
// Branch target = PC + ImmExt
// ============================================================

module Adder(in_1, in_2, Sum_out);

input [31:0] in_1;
input [31:0] in_2;

output [31:0] Sum_out;

assign Sum_out = in_1 + in_2;

endmodule


// ============================================================
// TOP LEVEL
//
// Synthesizable processor top.
//
// PC_out exposes the existing program counter so that the
// processor remains observable to FPGA synthesis/implementation.
// This does not alter the processor datapath.
// ============================================================

module top(clk, reset, PC_out);

input clk;
input reset;
output [31:0] PC_out;


// ------------------------------------------------------------
// Main datapath wires
// ------------------------------------------------------------

wire [31:0] PC_top;
wire [31:0] instruction_top;

wire [31:0] Rd1_top;
wire [31:0] Rd2_top;

wire [31:0] ImmExt_top;
wire [31:0] mux1_top;

wire [31:0] Sum_out_top;
wire [31:0] NextoPC_top;
wire [31:0] PCin_top;

wire [31:0] address_top;

wire [31:0] Memdata_top;
wire [31:0] WriteBack_top;


// ------------------------------------------------------------
// Control signals
// ------------------------------------------------------------

wire RegWrite_top;
wire ALUSrc_top;
wire zero_top;
wire branch_top;

wire sel2_top;

wire MemtoReg_top;
wire MemWrite_top;
wire MemRead_top;

wire [1:0] ALUOp_top;
wire [3:0] control_top;


// ============================================================
// Program Counter
// ============================================================

Program_Counter PC(
    .clk(clk),
    .reset(reset),
    .PC_in(PCin_top),
    .PC_out(PC_top)
);


// ============================================================
// PC + 4
// ============================================================

PCplus4 PC_Adder(
    .fromPC(PC_top),
    .NextoPC(NextoPC_top)
);


// ============================================================
// Instruction Memory
// ============================================================

Instruction_Memory Inst_Memory(
    .clk(clk),
    .reset(reset),
    .read_address(PC_top),
    .instruction_out(instruction_top)
);


// ============================================================
// Register File
// ============================================================

Reg_File Reg_File(
    .clk(clk),
    .reset(reset),
    .RegWrite(RegWrite_top),
    .Rs1(instruction_top[19:15]),
    .Rs2(instruction_top[24:20]),
    .Rd(instruction_top[11:7]),
    .Write_data(WriteBack_top),
    .read_data1(Rd1_top),
    .read_data2(Rd2_top)
);


// ============================================================
// Immediate Generator
// ============================================================

ImmGen ImmGen(
    .Opcode(instruction_top[6:0]),
    .instruction(instruction_top),
    .ImmExt(ImmExt_top)
);


// ============================================================
// Control Unit
// ============================================================

Control_Unit Control_Unit(
    .instruction(instruction_top[6:0]),
    .Branch(branch_top),
    .MemRead(MemRead_top),
    .MemtoReg(MemtoReg_top),
    .ALUOp(ALUOp_top),
    .MemWrite(MemWrite_top),
    .ALUSrc(ALUSrc_top),
    .RegWrite(RegWrite_top)
);


// ============================================================
// ALU Control
// ============================================================

ALU_Control ALU_Control(
    .ALUOp(ALUOp_top),
    .fun7(instruction_top[30]),
    .fun3(instruction_top[14:12]),
    .Control_out(control_top)
);


// ============================================================
// ALU Mux
// ============================================================

Mux1 ALU_mux(
    .sel1(ALUSrc_top),
    .A1(Rd2_top),
    .B1(ImmExt_top),
    .Mux1_out(mux1_top)
);


// ============================================================
// ALU
// ============================================================

ALU_unit ALU(
    .A(Rd1_top),
    .B(mux1_top),
    .Control_in(control_top),
    .ALU_Result(address_top),
    .zero(zero_top)
);


// ============================================================
// Branch Target Adder
// ============================================================

Adder Adder(
    .in_1(PC_top),
    .in_2(ImmExt_top),
    .Sum_out(Sum_out_top)
);


// ============================================================
// Branch AND Logic
// ============================================================

AND_logic AND(
    .branch(branch_top),
    .zero(zero_top),
    .and_out(sel2_top)
);


// ============================================================
// Next PC Mux
// ============================================================

Mux2 Adder_mux(
    .sel2(sel2_top),
    .A2(NextoPC_top),
    .B2(Sum_out_top),
    .Mux2_out(PCin_top)
);


// ============================================================
// Data Memory
// ============================================================

Data_Memory Data_mem(
    .clk(clk),
    .reset(reset),
    .MemWrite(MemWrite_top),
    .MemRead(MemRead_top),
    .read_address(address_top),
    .Write_data(Rd2_top),
    .MemData_out(Memdata_top)
);


// ============================================================
// Write-back Mux
// ============================================================

Mux3 Memory_mux(
    .sel3(MemtoReg_top),
    .A3(address_top),
    .B3(Memdata_top),
    .Mux3_out(WriteBack_top)
);


// ============================================================
// Hardware-observable processor output
//
// Exposes the existing program counter.
// No datapath logic is changed.
// ============================================================

assign PC_out = PC_top;

endmodule


// ============================================================
// TESTBENCH
//
// This testbench verifies:
//
// 1. LW
// 2. ADD
// 3. SUB
// 4. AND
// 5. OR
// 6. SW
// 7. BEQ
//
// Expected:
//
// x1 = 5
// x2 = 10
// x3 = 15
// x4 = 5
// x5 = 0
// x6 = 15
//
// D_Memory[2] = 15
// D_Memory[3] = 0  <-- SW skipped by BEQ
// D_Memory[4] = 15
// ============================================================

module tb_top;

reg clk;
reg reset;

wire [31:0] pc_monitor;

top uut(
    .clk(clk),
    .reset(reset),
    .PC_out(pc_monitor)
);


// ------------------------------------------------------------
// Clock
// ------------------------------------------------------------

initial
begin
    clk = 1'b0;

    forever
        #5 clk = ~clk;
end


// ------------------------------------------------------------
// Reset and verification
// ------------------------------------------------------------

initial
begin

    reset = 1'b1;

    #12;

    reset = 1'b0;


    // --------------------------------------------------------
    // Allow processor to execute program
    // --------------------------------------------------------

    #120;


    // --------------------------------------------------------
    // Display results
    // --------------------------------------------------------

    $display("==============================================");
    $display("RISC-V SINGLE-CYCLE PROCESSOR TEST");
    $display("==============================================");

    $display("x1 = %0d", uut.Reg_File.Registers[1]);
    $display("x2 = %0d", uut.Reg_File.Registers[2]);
    $display("x3 = %0d", uut.Reg_File.Registers[3]);
    $display("x4 = %0d", uut.Reg_File.Registers[4]);
    $display("x5 = %0d", uut.Reg_File.Registers[5]);
    $display("x6 = %0d", uut.Reg_File.Registers[6]);

    $display("Memory[2] = %0d", uut.Data_mem.D_Memory[2]);
    $display("Memory[3] = %0d", uut.Data_mem.D_Memory[3]);
    $display("Memory[4] = %0d", uut.Data_mem.D_Memory[4]);


    // --------------------------------------------------------
    // Automatic checks
    // --------------------------------------------------------

    if(uut.Reg_File.Registers[1] == 32'd5)
        $display("PASS: LW x1");
    else
        $display("FAIL: LW x1");


    if(uut.Reg_File.Registers[2] == 32'd10)
        $display("PASS: LW x2");
    else
        $display("FAIL: LW x2");


    if(uut.Reg_File.Registers[3] == 32'd15)
        $display("PASS: ADD x3");
    else
        $display("FAIL: ADD x3");


    if(uut.Reg_File.Registers[4] == 32'd5)
        $display("PASS: SUB x4");
    else
        $display("FAIL: SUB x4");


    if(uut.Reg_File.Registers[5] == 32'd0)
        $display("PASS: AND x5");
    else
        $display("FAIL: AND x5");


    if(uut.Reg_File.Registers[6] == 32'd15)
        $display("PASS: OR x6");
    else
        $display("FAIL: OR x6");


    if(uut.Data_mem.D_Memory[2] == 32'd15)
        $display("PASS: SW x3");
    else
        $display("FAIL: SW x3");


    if(uut.Data_mem.D_Memory[3] == 32'd0)
        $display("PASS: BEQ branch taken / instruction skipped");
    else
        $display("FAIL: BEQ branch");


    if(uut.Data_mem.D_Memory[4] == 32'd15)
        $display("PASS: instruction after BEQ");
    else
        $display("FAIL: instruction after BEQ");


    // --------------------------------------------------------
    // Finish simulation
    // --------------------------------------------------------

    $display("==============================================");
    $display("SIMULATION COMPLETE");
    $display("==============================================");

    #10;

    $finish;

end

endmodule