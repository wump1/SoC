`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/loop.imem.hex"
`define TEST_DMEM_HEX "build/programs/loop.dmem.hex"

module tb_loop;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(2000);

    tb_check(dut.u_regfile.regs[1] === 32'd55, $sformatf("sum(1..10) == 55, got %0d", dut.u_regfile.regs[1]));
    tb_check(dut.u_regfile.regs[2] === 32'd11, "loop index reached its limit");

    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_loop");
  end
endmodule
