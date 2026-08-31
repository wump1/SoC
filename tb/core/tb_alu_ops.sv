`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/alu_ops.imem.hex"
`define TEST_DMEM_HEX "build/programs/alu_ops.dmem.hex"

module tb_alu_ops;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(1000);

    tb_check(dut.u_regfile.regs[5]  === 32'h0000000B, "x5  ANDI negative & mask");
    tb_check(dut.u_regfile.regs[6]  === 32'hFFFFFFFF, "x6  ORI sign-extended -1");
    tb_check(dut.u_regfile.regs[7]  === 32'h00000000, "x7  XORI cancels to 0");
    tb_check(dut.u_regfile.regs[8]  === 32'd1,        "x8  SLTI signed taken");
    tb_check(dut.u_regfile.regs[9]  === 32'd0,        "x9  SLTIU unsigned not-taken");
    tb_check(dut.u_regfile.regs[11] === 32'h80000000, "x11 SLLI by 31");
    tb_check(dut.u_regfile.regs[12] === 32'h00000001, "x12 SRLI logical by 31");
    tb_check(dut.u_regfile.regs[13] === 32'hFFFFFFFF, "x13 SRAI arithmetic by 31 sign-fills");
    tb_check(dut.u_regfile.regs[14] === 32'hF8000000, "x14 SRAI by 4 sign-fills");
    tb_check(dut.u_regfile.regs[15] === 32'hFFFFFFFD, "x15 SUB negative result");
    tb_check(dut.u_regfile.regs[16] === 32'd3,         "x16 AND");
    tb_check(dut.u_regfile.regs[17] === 32'hFFFFFFFB,  "x17 OR");
    tb_check(dut.u_regfile.regs[18] === 32'hFFFFFFFC,  "x18 XOR");
    tb_check(dut.u_regfile.regs[19] === 32'd8,          "x19 SLL");
    tb_check(dut.u_regfile.regs[20] === 32'h10000000,   "x20 SRL logical");
    tb_check(dut.u_regfile.regs[21] === 32'hF0000000,   "x21 SRA arithmetic");
    tb_check(dut.u_regfile.regs[22] === 32'd1,           "x22 SLT signed taken");
    tb_check(dut.u_regfile.regs[23] === 32'd0,           "x23 SLTU unsigned not-taken");
    tb_check(dut.u_regfile.regs[24] === 32'd0,           "x24 SLT signed reversed not-taken");
    tb_check(dut.u_regfile.regs[25] === 32'd1,           "x25 SLTU unsigned reversed taken");
    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_alu_ops");
  end
endmodule
