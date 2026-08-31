`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/loadstore.imem.hex"
`define TEST_DMEM_HEX "build/programs/loadstore.dmem.hex"

module tb_loadstore;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(1000);

    tb_check(dut.u_regfile.regs[4]  === -32'sd1000,   "x4  word roundtrip == -1000");

    // Direct memory inspection: each SB landed in its own byte lane and
    // didn't disturb its neighbors.
    tb_check(dut_mem.dmem_arr[4] === 8'h7A, "byte lane 0 == 0x7A");
    tb_check(dut_mem.dmem_arr[5] === 8'hFF, "byte lane 1 == 0xFF");
    tb_check(dut_mem.dmem_arr[6] === 8'h00, "byte lane 2 == 0x00");
    tb_check(dut_mem.dmem_arr[7] === 8'h55, "byte lane 3 == 0x55");
    tb_check(dut.u_regfile.regs[8]  === 32'h5500FF7A, "x8  LW sees all four byte lanes assembled");

    tb_check(dut.u_regfile.regs[9]  === 32'h0000007A, "x9  LB sign-extends a positive byte");
    tb_check(dut.u_regfile.regs[10] === 32'hFFFFFFFF, "x10 LB sign-extends a negative byte");
    tb_check(dut.u_regfile.regs[11] === 32'h000000FF, "x11 LBU zero-extends the same byte");

    tb_check(dut.u_regfile.regs[13] === 32'hFFFFFFFE, "x13 LH sign-extends a negative halfword");
    tb_check(dut.u_regfile.regs[14] === 32'h0000FFFE, "x14 LHU zero-extends the same halfword");

    tb_check(dut.u_regfile.regs[16] === 32'h1234FFFE, "x16 upper-halfword store lands in the right lane");

    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_loadstore");
  end
endmodule
