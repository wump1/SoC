`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/hazard_stress.imem.hex"
`define TEST_DMEM_HEX "build/programs/hazard_stress.dmem.hex"

// Runs against whichever core `core_harness.svh` is told to instantiate
// (defaults to rv32_single; pass -DCORE_DUT=rv32_core to target the
// pipeline). On rv32_single every one of these checks is trivially true
// (no pipeline, no hazards); on rv32_core they are the actual hazard
// regression this program exists for.
module tb_hazard_stress;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(2000);

    tb_check(dut.u_regfile.regs[5] === 32'd77, "x5 load result");
    tb_check(dut.u_regfile.regs[6] === 32'd78, "x6 load-use hazard: dependent instruction right after the load");
    tb_check(dut.u_regfile.regs[7] === 32'd154, "x7 load-use: second instruction after the load");

    tb_check(dut.u_regfile.regs[8] === 32'd4, "x8 tight 4-instruction forwarding chain");

    tb_check(dut.u_regfile.regs[11] === 32'd30, "x11 sum of two fresh values");
    tb_check(dut.u_regfile.regs[12] === 32'd60, "x12 distance-1 forwarding (EX/MEM), both operands");

    tb_check(dut.u_regfile.regs[15] === 32'd10, "x15 distance-2 forwarding (MEM/WB)");

    tb_check(dut.u_regfile.regs[19] === 32'd14, "x19 distance-3 forwarding (regfile tier-0 bypass)");

    tb_check(dut.u_regfile.regs[22] === 32'd0,
      $sformatf("x22 wrong-path store after a taken branch never committed, got %0d", dut.u_regfile.regs[22]));

    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_hazard_stress");
  end
endmodule
