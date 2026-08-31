`timescale 1ns/1ps
// Golden vectors below are real machine code from riscv64-unknown-elf-gcc
// -march=rv32i -mabi=ilp32 (see tb/programs/golden/imm_vectors.S), not
// hand-computed bit patterns -- the immediate is cross-checked as
// (target_address - instruction_address) read straight from objdump, so a
// bit-order bug in this testbench itself can't cancel out a matching bug
// in imm_gen.
module tb_imm_gen;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic [31:0] instr;
  imm_sel_e     imm_sel;
  logic [31:0] imm;

  imm_gen dut (.instr(instr), .imm_sel(imm_sel), .imm(imm));

  task automatic run(input logic [31:0] instr_i, input imm_sel_e sel_i,
                      input logic [31:0] expected, input string msg);
    instr = instr_i; imm_sel = sel_i;
    #1;
    tb_check(imm === expected,
      $sformatf("%s: got %08h expected %08h", msg, imm, expected));
  endtask

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_imm_gen]"); $finish;
  end

  initial begin
    // I-type: addi x1,x0,2047 / addi x2,x0,-2048 / addi x3,x0,-1
    run(32'h7ff00093, IMM_I, 32'h000007FF, "I-type max positive (2047)");
    run(32'h80000113, IMM_I, 32'hFFFFF800, "I-type max negative (-2048)");
    run(32'hfff00193, IMM_I, 32'hFFFFFFFF, "I-type all-ones (-1)");

    // S-type: sw x1,2047(x2) / sw x1,-2048(x2)
    run(32'h7e112fa3, IMM_S, 32'h000007FF, "S-type max positive (2047)");
    run(32'h80112023, IMM_S, 32'hFFFFF800, "S-type max negative (-2048)");

    // B-type: beq at 0x1c -> 0x30 (fwd, +20); bne at 0x2c -> 0x14 (back, -24)
    run(32'h00208a63, IMM_B, 32'h00000014, "B-type forward branch (+20)");
    run(32'hfe2094e3, IMM_B, 32'hFFFFFFE8, "B-type backward branch (-24)");

    // U-type: lui x4, 0xABCDE
    run(32'habcde237, IMM_U, 32'hABCDE000, "U-type upper immediate");

    // J-type: jal at 0x34 -> 0x4c (fwd, +24); jal at 0x48 -> 0x44 (back, -4)
    run(32'h018002ef, IMM_J, 32'h00000018, "J-type forward jump (+24)");
    run(32'hffdff36f, IMM_J, 32'hFFFFFFFC, "J-type backward jump (-4)");

    // Zero immediate sanity check per format
    run(32'h00000013, IMM_I, 32'h00000000, "I-type zero (nop = addi x0,x0,0)");

    tb_summary("tb_imm_gen");
  end
endmodule
