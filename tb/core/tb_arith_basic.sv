`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/arith_basic.imem.hex"
`define TEST_DMEM_HEX "build/programs/arith_basic.dmem.hex"

// M2 exit criterion: a self-checking ADDI/ADD/SUB program passes, proving
// PC -> fetch -> decode -> regfile -> ALU -> writeback end to end.
module tb_arith_basic;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(1000);

    tb_check(dut.u_regfile.regs[1] === 32'd10, $sformatf("x1 == 10, got %0d", dut.u_regfile.regs[1]));
    tb_check(dut.u_regfile.regs[2] === 32'd20, $sformatf("x2 == 20, got %0d", dut.u_regfile.regs[2]));
    tb_check(dut.u_regfile.regs[3] === 32'd30, $sformatf("x3 == 30, got %0d", dut.u_regfile.regs[3]));
    tb_check(dut.u_regfile.regs[4] === 32'd20, $sformatf("x4 == 20, got %0d", dut.u_regfile.regs[4]));
    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_arith_basic");
  end
endmodule
