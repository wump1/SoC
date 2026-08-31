`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/sum_test.imem.hex"
`define TEST_DMEM_HEX "build/programs/sum_test.dmem.hex"

// First bare-metal C program (M7): real function call/return through the
// stack, a loop, and globals -- compiled by the real GNU toolchain, not
// hand-assembled. g_result/g_done are checked directly in memory (their
// addresses come from build/programs/sum_test.dump, the same
// read-the-real-toolchain-output discipline as every other golden-vector
// test in this suite), the same way tb_loadstore.sv checks memory.
module tb_sum_test;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(3000);

    tb_check({dut_mem.dmem_arr[3], dut_mem.dmem_arr[2], dut_mem.dmem_arr[1], dut_mem.dmem_arr[0]} === 32'd55,
      $sformatf("g_result (0x10000000) == sum(1..10) == 55, got %0d",
        {dut_mem.dmem_arr[3], dut_mem.dmem_arr[2], dut_mem.dmem_arr[1], dut_mem.dmem_arr[0]}));
    tb_check({dut_mem.dmem_arr[7], dut_mem.dmem_arr[6], dut_mem.dmem_arr[5], dut_mem.dmem_arr[4]} === 32'd1,
      "g_done (0x10000004) == 1: main() ran to completion");

    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_sum_test");
  end
endmodule
