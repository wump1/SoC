`timescale 1ns/1ps
module tb_regfile;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic        clk = 0;
  logic        reset_n;
  logic        we;
  logic [4:0]  waddr;
  logic [31:0] wdata;
  logic [4:0]  raddr1, raddr2;
  logic [31:0] rdata1, rdata2;

  regfile dut (.*);

  always #5 clk = ~clk;

  // Sets up we/waddr/wdata, lets the DUT's always_ff sample them on the
  // edge, and only clears `we` strictly *after* that edge (#1 past it).
  // Clearing we at the same simulation time as the edge would race the
  // DUT's own @(posedge clk) block -- which one a simulator runs first is
  // unspecified, so it can silently sample we=0 and drop the write.
  task automatic do_write(input logic [4:0] a, input logic [31:0] d);
    we = 1; waddr = a; wdata = d;
    @(posedge clk);
    #1;
    we = 0;
  endtask

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_regfile]"); $finish;
  end

  initial begin
    we = 0; waddr = 0; wdata = 0; raddr1 = 0; raddr2 = 0;
    reset_n = 0;
    @(posedge clk); #1;
    reset_n = 1;

    // x0 always reads zero before any writes.
    raddr1 = 5'd0; raddr2 = 5'd1;
    #1;
    tb_check(rdata1 === 32'h0, "x0 reads zero at reset");

    // x0 ignores writes: attempt to write, then confirm it still reads zero.
    do_write(5'd0, 32'hFFFFFFFF);
    raddr1 = 5'd0;
    #1;
    tb_check(rdata1 === 32'h0, "x0 discards writes and still reads zero");

    // Normal write then read-after-write on a later cycle.
    do_write(5'd1, 32'hCAFEBABE);
    raddr1 = 5'd1;
    #1;
    tb_check(rdata1 === 32'hCAFEBABE, $sformatf("x1 read-after-write, got %08h", rdata1));

    // Distinct register indices stay independent.
    do_write(5'd2, 32'h11111111);
    do_write(5'd31, 32'h1F1F1F1F);
    raddr1 = 5'd1; raddr2 = 5'd2;
    #1;
    tb_check(rdata1 === 32'hCAFEBABE, "x1 unaffected by later writes to x2");
    tb_check(rdata2 === 32'h11111111, $sformatf("x2 read, got %08h", rdata2));
    raddr1 = 5'd31;
    #1;
    tb_check(rdata1 === 32'h1F1F1F1F, $sformatf("x31 (top index) read, got %08h", rdata1));

    // Both read ports can read the same register simultaneously.
    raddr1 = 5'd1; raddr2 = 5'd1;
    #1;
    tb_check(rdata1 === rdata2 && rdata1 === 32'hCAFEBABE, "both read ports agree on the same address");

    // Write-first same-cycle bypass: read the address being written THIS
    // cycle and expect the new value combinationally, not the old one.
    raddr1 = 5'd5;
    we = 1; waddr = 5'd5; wdata = 32'h5A5A5A5A;
    #1;
    tb_check(rdata1 === 32'h5A5A5A5A,
      $sformatf("write-first bypass: same-cycle read sees new data, got %08h", rdata1));
    @(posedge clk);
    #1;
    we = 0;
    tb_check(rdata1 === 32'h5A5A5A5A, "value persists on the following cycle");

    // Reset clears all previously written registers.
    reset_n = 0;
    @(posedge clk); #1;
    reset_n = 1;
    raddr1 = 5'd1; raddr2 = 5'd5;
    #1;
    tb_check(rdata1 === 32'h0, "reset clears x1");
    tb_check(rdata2 === 32'h0, "reset clears x5");

    tb_summary("tb_regfile");
  end
endmodule
