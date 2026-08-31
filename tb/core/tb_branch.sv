`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/branch.imem.hex"
`define TEST_DMEM_HEX "build/programs/branch.dmem.hex"

module tb_branch;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(2000);

    tb_check(dut.u_regfile.regs[31] === 32'd0, "poison canary x31 stayed 0: no branch took the wrong path");

    tb_check(dut.u_regfile.regs[4]  === 32'd111, "BEQ not-taken fell through");
    tb_check(dut.u_regfile.regs[5]  === 32'd222, "BNE not-taken fell through");
    tb_check(dut.u_regfile.regs[8]  === 32'd333, "BLT not-taken fell through");
    tb_check(dut.u_regfile.regs[9]  === 32'd444, "BGE not-taken fell through");
    tb_check(dut.u_regfile.regs[10] === 32'd555, "BLTU not-taken fell through");
    tb_check(dut.u_regfile.regs[11] === 32'd666, "BGEU not-taken fell through");

    tb_check(dut.u_regfile.regs[12] === 32'd0, "backward-branch loop counted 3 down to 0");

    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_branch");
  end
endmodule
