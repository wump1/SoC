`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/jump.imem.hex"
`define TEST_DMEM_HEX "build/programs/jump.dmem.hex"

// Expected link-register/target values below are read directly from
// build/programs/jump.dump (real linked addresses), not computed by hand.
module tb_jump;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(1000);

    tb_check(dut.u_regfile.regs[31] === 32'd0, "poison canary x31 stayed 0: every jump actually redirected");

    tb_check(dut.u_regfile.regs[1] === 32'h00000004, "x1  JAL link == PC+4 of the jal itself");
    tb_check(dut.u_regfile.regs[2] === 32'd111,       "x2  landed at forward_target");
    tb_check(dut.u_regfile.regs[3] === 32'h00000010,  "x3  call-site JAL link == PC+4");
    tb_check(dut.u_regfile.regs[5] === 32'd333,        "x5  entered call_func");
    tb_check(dut.u_regfile.regs[4] === 32'd222,         "x4  resumed after JALR return");
    tb_check(dut.u_regfile.regs[6] === 32'h00000039,    "x6  la+1 kept its LSB (JALR clears the *target*, not rs1)");
    tb_check(dut.u_regfile.regs[7] === 32'h00000034,    "x7  JALR link == PC+4 of the jalr itself");
    tb_check(dut.u_regfile.regs[8] === 32'd444,          "x8  JALR target had its LSB cleared, landing exactly on jalr_target");

    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_jump");
  end
endmodule
