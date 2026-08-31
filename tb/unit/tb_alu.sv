`timescale 1ns/1ps
module tb_alu;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic [31:0] a, b;
  alu_op_e     op;
  logic [31:0] result;

  alu dut (.a(a), .b(b), .op(op), .result(result));

  task automatic run(input logic [31:0] a_i, input logic [31:0] b_i,
                      input alu_op_e op_i, input logic [31:0] expected,
                      input string msg);
    a = a_i; b = b_i; op = op_i;
    #1;
    tb_check(result === expected,
      $sformatf("%s: got %08h expected %08h", msg, result, expected));
  endtask

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_alu]"); $finish;
  end

  initial begin
    // ADD
    run(32'd5, 32'd3, ALU_ADD, 32'd8, "ADD 5+3");
    run(-32'd5, 32'd3, ALU_ADD, -32'd2, "ADD -5+3");
    run(32'h7FFFFFFF, 32'd1, ALU_ADD, 32'h80000000, "ADD overflow wrap");
    run(32'd0, 32'd0, ALU_ADD, 32'd0, "ADD 0+0");

    // SUB
    run(32'd5, 32'd3, ALU_SUB, 32'd2, "SUB 5-3");
    run(32'd3, 32'd5, ALU_SUB, -32'd2, "SUB 3-5");
    run(32'h80000000, 32'd1, ALU_SUB, 32'h7FFFFFFF, "SUB underflow wrap");

    // Logic
    run(32'hF0F0F0F0, 32'h0FF00FF0, ALU_AND, 32'h00F000F0, "AND");
    run(32'hF0F0F0F0, 32'h0FF00FF0, ALU_OR,  32'hFFF0FFF0, "OR");
    run(32'hF0F0F0F0, 32'h0FF00FF0, ALU_XOR, 32'hFF00FF00, "XOR");
    run(32'hAAAAAAAA, 32'h55555555, ALU_XOR, 32'hFFFFFFFF, "XOR complement");

    // Shifts: shamt uses only b[4:0] (RV32 rule)
    run(32'h00000001, 32'd31, ALU_SLL, 32'h80000000, "SLL by 31");
    run(32'h00000001, 32'd0,  ALU_SLL, 32'h00000001, "SLL by 0");
    run(32'h00000001, 32'd32, ALU_SLL, 32'h00000001, "SLL shamt masks to 0 (b=32)");
    run(32'h80000000, 32'd31, ALU_SRL, 32'h00000001, "SRL by 31 (logical, no sign fill)");
    run(32'h80000000, 32'd31, ALU_SRA, 32'hFFFFFFFF, "SRA by 31 (arithmetic, sign fills)");
    run(32'h7FFFFFFF, 32'd31, ALU_SRA, 32'h00000000, "SRA positive stays 0");
    run(32'hFFFFFFFF, 32'd4,  ALU_SRA, 32'hFFFFFFFF, "SRA -1 stays -1");

    // SLT (signed) vs SLTU (unsigned) on the same bit patterns
    run(32'hFFFFFFFF, 32'h00000001, ALU_SLT,  32'd1, "SLT -1 < 1 (signed)");
    run(32'hFFFFFFFF, 32'h00000001, ALU_SLTU, 32'd0, "SLTU 0xFFFFFFFF < 1 is false (unsigned)");
    run(32'h80000000, 32'h7FFFFFFF, ALU_SLT,  32'd1, "SLT INT_MIN < INT_MAX");
    run(32'h80000000, 32'h7FFFFFFF, ALU_SLTU, 32'd0, "SLTU 0x80000000 < 0x7FFFFFFF is false");
    run(32'd5, 32'd5, ALU_SLT,  32'd0, "SLT equal -> false");
    run(32'd5, 32'd5, ALU_SLTU, 32'd0, "SLTU equal -> false");

    // PASSB (used by LUI)
    run(32'hDEADBEEF, 32'h12345000, ALU_PASSB, 32'h12345000, "PASSB ignores a");

    tb_summary("tb_alu");
  end
endmodule
