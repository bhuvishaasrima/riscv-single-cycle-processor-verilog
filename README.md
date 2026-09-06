# RISC-V Single-Cycle Processor in Verilog

## Overview

This project implements a 32-bit RISC-V single-cycle processor using Verilog-2001.

The processor uses a modular datapath consisting of a program counter, instruction memory, register file, immediate generator, control unit, ALU control, ALU, data memory, multiplexers, and branch logic.

The supported instruction set is intentionally limited to:

- ADD
- SUB
- AND
- OR
- LW
- SW
- BEQ

## Key Features

- 32-bit RISC-V single-cycle processor
- Verilog-2001 RTL implementation
- Modular datapath and control architecture
- R-type arithmetic and logical operations
- Load/store memory operations
- BEQ conditional branching
- 32-register register file
- RISC-V x0 behavior
- Instruction and data memory interfaces
- Functional simulation testbench

## Supported Instructions

| Instruction | Type | Operation |
|---|---|---|
| ADD | R-type | `rd = rs1 + rs2` |
| SUB | R-type | `rd = rs1 - rs2` |
| AND | R-type | `rd = rs1 & rs2` |
| OR | R-type | `rd = rs1 \| rs2` |
| LW | I-type | Load word from data memory |
| SW | S-type | Store word to data memory |
| BEQ | B-type | Branch if `rs1 == rs2` |

No other instructions are implemented.

## Processor Architecture

The processor follows a single-cycle datapath in which each instruction completes its required operations within one clock cycle.

The main datapath contains:

- Program Counter
- PC + 4 logic
- Instruction Memory
- Register File
- Immediate Generator
- Control Unit
- ALU Control
- ALU
- Branch Target Adder
- Branch Decision Logic
- Data Memory
- Write-back Multiplexer

The processor top-level module is `top`.

## Main RTL Modules

### Program Counter

Stores the current program counter and updates it on the rising edge of the clock. The PC is reset to zero.

### Instruction Memory

Provides instruction data based on the program counter address.

### Register File

Implements 32 general-purpose 32-bit registers with two read ports and one write port.

Register `x0` follows the RISC-V convention:

- Reads from `x0` return zero.
- Writes to `x0` are prevented.

### Immediate Generator

Generates the required sign-extended immediate values for the supported I-type, S-type, and B-type instructions.

### Control Unit

Generates the main datapath control signals based on the instruction opcode.

### ALU Control

Determines the ALU operation using the instruction's control fields.

### ALU

Performs:

- ADD
- SUB
- AND
- OR

The ALU also provides a zero result indication used by BEQ.

### Data Memory

Provides the data-memory interface required by LW and SW.

### Multiplexers and Branch Logic

Multiplexers select ALU operands, the next PC source, and write-back data.

## Datapath Description

### R-type instructions

For ADD, SUB, AND, and OR:

```text
PC
 ↓
Instruction Memory
 ↓
Register File
 ↓
ALU
 ↓
Register File
