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
