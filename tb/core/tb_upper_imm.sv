`timescale 1ns/1ps
`define TEST_IMEM_HEX "build/programs/upper_imm.imem.hex"
`define TEST_DMEM_HEX "build/programs/upper_imm.dmem.hex"

// Expected values read directly from build/programs/upper_imm.dump.
module tb_upper_imm;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"
  `include "core_harness.svh"

  initial begin
    apply_reset();
    wait_for_halt(500);

    tb_check(dut.u_regfile.regs[1] === 32'hABCDE000, "x1 LUI places the immediate in bits [31:12]");
    tb_check(dut.u_regfile.regs[2] === 32'h00000004, "x2 AUIPC 0 == this instruction's own PC");
    tb_check(dut.u_regfile.regs[3] === 32'h00001008, "x3 AUIPC 1 == PC + 0x1000");

    tb_check(!sticky_illegal, "no illegal-instruction decode occurred");
    tb_check(!sticky_misaligned, "no misaligned access occurred");

    tb_summary("tb_upper_imm");
  end
endmodule
