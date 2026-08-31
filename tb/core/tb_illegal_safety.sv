`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/illegal_safety.imem.hex"
`define TEST_DMEM_HEX "build/programs/illegal_safety.dmem.hex"

// Unlike every other core-level test, this one *expects* sticky_illegal to
// fire -- sw/asm/illegal_safety.S deliberately injects an unsupported
// encoding whose rd field aliases the poison canary x31. The property
// under test is that decoding it is a strict no-op: it must not write
// x31, must not write memory, and execution must simply continue at the
// next instruction rather than corrupting state or hanging.
module tb_illegal_safety;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(500);

    tb_check(sticky_illegal, "the injected .word was actually decoded as illegal (test is exercising the intended path)");
    tb_check(dut.u_regfile.regs[31] === 32'd0, "illegal instruction did not write x31 despite rd aliasing it");
    tb_check(dut.u_regfile.regs[1] === 32'd10, "x1 set before the illegal word is unaffected");
    tb_check(dut.u_regfile.regs[2] === 32'd20, "x2 set after the illegal word proves execution continued normally");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_illegal_safety");
  end
endmodule
