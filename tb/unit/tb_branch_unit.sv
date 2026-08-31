`timescale 1ns/1ps
module tb_branch_unit;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic [31:0] rs1_data, rs2_data;
  logic [2:0]  funct3;
  logic        taken;

  branch_unit dut (.rs1_data(rs1_data), .rs2_data(rs2_data),
                    .funct3(funct3), .taken(taken));

  task automatic run(input logic [31:0] a, input logic [31:0] b,
                      input logic [2:0] f3, input logic expected,
                      input string msg);
    rs1_data = a; rs2_data = b; funct3 = f3;
    #1;
    tb_check(taken === expected, $sformatf("%s: got %0d expected %0d", msg, taken, expected));
  endtask

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_branch_unit]"); $finish;
  end

  initial begin
    // BEQ / BNE
    run(32'd5, 32'd5, F3_BEQ, 1'b1, "BEQ equal -> taken");
    run(32'd5, 32'd6, F3_BEQ, 1'b0, "BEQ unequal -> not taken");
    run(32'd5, 32'd5, F3_BNE, 1'b0, "BNE equal -> not taken");
    run(32'd5, 32'd6, F3_BNE, 1'b1, "BNE unequal -> taken");

    // BLT/BGE signed, using values that differ under signed vs unsigned reading
    run(32'hFFFFFFFF, 32'h00000001, F3_BLT, 1'b1, "BLT -1 < 1 (signed) -> taken");
    run(32'hFFFFFFFF, 32'h00000001, F3_BGE, 1'b0, "BGE -1 >= 1 (signed) -> not taken");
    run(32'h80000000, 32'h7FFFFFFF, F3_BLT, 1'b1, "BLT INT_MIN < INT_MAX -> taken");
    run(32'h00000001, 32'hFFFFFFFF, F3_BGE, 1'b1, "BGE 1 >= -1 (signed) -> taken");
    run(32'd5, 32'd5, F3_BLT, 1'b0, "BLT equal -> not taken");
    run(32'd5, 32'd5, F3_BGE, 1'b1, "BGE equal -> taken");

    // BLTU/BGEU unsigned: same bit patterns as above but opposite outcome
    run(32'hFFFFFFFF, 32'h00000001, F3_BLTU, 1'b0, "BLTU 0xFFFFFFFF < 1 (unsigned) -> not taken");
    run(32'hFFFFFFFF, 32'h00000001, F3_BGEU, 1'b1, "BGEU 0xFFFFFFFF >= 1 (unsigned) -> taken");
    run(32'h80000000, 32'h7FFFFFFF, F3_BLTU, 1'b0, "BLTU 0x80000000 < 0x7FFFFFFF (unsigned) -> not taken");
    run(32'd5, 32'd5, F3_BLTU, 1'b0, "BLTU equal -> not taken");
    run(32'd5, 32'd5, F3_BGEU, 1'b1, "BGEU equal -> taken");

    tb_summary("tb_branch_unit");
  end
endmodule
