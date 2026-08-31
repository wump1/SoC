`timescale 1ns/1ps
module tb_pc;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic        clk = 0;
  logic        reset_n;
  logic        en;
  logic [31:0] pc_next;
  logic [31:0] pc_q;

  pc dut (.clk(clk), .reset_n(reset_n), .en(en), .pc_next(pc_next), .pc_q(pc_q));

  always #5 clk = ~clk;

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_pc]"); $finish;
  end

  initial begin
    reset_n = 0; en = 1; pc_next = 32'hDEADBEEF;
    @(posedge clk); #1;
    tb_check(pc_q === RESET_VECTOR, $sformatf("reset drives pc_q to RESET_VECTOR, got %08h", pc_q));

    reset_n = 1;
    pc_next = 32'h00000004;
    @(posedge clk); #1;
    tb_check(pc_q === 32'h00000004, $sformatf("normal advance to pc_next, got %08h", pc_q));

    pc_next = 32'h00000008;
    @(posedge clk); #1;
    tb_check(pc_q === 32'h00000008, $sformatf("normal advance again, got %08h", pc_q));

    // Stall: en=0 must hold pc_q even though pc_next changes.
    en = 0;
    pc_next = 32'hFFFFFFFF;
    @(posedge clk); #1;
    tb_check(pc_q === 32'h00000008, $sformatf("en=0 holds pc_q, got %08h", pc_q));
    @(posedge clk); #1;
    tb_check(pc_q === 32'h00000008, $sformatf("en=0 continues to hold pc_q, got %08h", pc_q));

    // Resume
    en = 1;
    pc_next = 32'h0000000C;
    @(posedge clk); #1;
    tb_check(pc_q === 32'h0000000C, $sformatf("resumes advancing after en=1, got %08h", pc_q));

    // Reset is synchronous: asserting reset_n combinationally must not
    // change pc_q until the next clock edge.
    reset_n = 0;
    #1;
    tb_check(pc_q === 32'h0000000C, "reset_n deasserted combinationally does not change pc_q before an edge");
    @(posedge clk); #1;
    tb_check(pc_q === RESET_VECTOR, $sformatf("reset takes effect on the clock edge, got %08h", pc_q));

    tb_summary("tb_pc");
  end
endmodule
