// Shared core-level testbench harness, textually included (not a module)
// so each test's top-level module can freely reference `dut.*` and
// `dut_mem.*` hierarchically for its own checks after the include.
//
// Before including this file, define:
//   `TEST_IMEM_HEX "path/to/program.imem.hex"
//   `TEST_DMEM_HEX "path/to/program.dmem.hex"
// and optionally:
//   `CORE_DUT rv32_core     (defaults to rv32_single if not defined)
//
// rv32_single and rv32_core expose the exact same port list, so the same
// harness -- and the same directed programs -- drive either one; this is
// what lets M6's regression suite and reference-model comparisons run
// unmodified against both cores (Section 9).
//
// Programs signal completion by jumping to themselves (`halt: jal x0,
// halt`, emitted by every directed test program): once the pipeline/core
// retires the same PC twice in a row, wait_for_halt() returns and the
// including testbench does its own tb_check() calls against final
// architectural state.
`ifndef CORE_DUT
`define CORE_DUT rv32_single
`endif

logic clk = 0;
logic reset_n;
always #5 clk = ~clk;

logic        imem_req;
logic [31:0] imem_addr, imem_rdata;
logic        imem_ready;
logic        dmem_req, dmem_we;
logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
logic [3:0]  dmem_wstrb;
logic        dmem_ready;
trace_t      trace;
logic        dbg_illegal, dbg_misaligned;

`CORE_DUT dut (
  .clk, .reset_n,
  .imem_req, .imem_addr, .imem_rdata, .imem_ready,
  .dmem_req, .dmem_we, .dmem_addr, .dmem_wdata, .dmem_wstrb, .dmem_rdata, .dmem_ready,
  .trace, .dbg_illegal, .dbg_misaligned
);

sram_model #(
  .IMEM_INIT_FILE(`TEST_IMEM_HEX),
  .DMEM_INIT_FILE(`TEST_DMEM_HEX)
) dut_mem (
  .clk,
  .i_req(imem_req), .i_addr(imem_addr), .i_rdata(imem_rdata), .i_ready(imem_ready),
  .d_req(dmem_req), .d_we(dmem_we), .d_addr(dmem_addr), .d_wdata(dmem_wdata),
  .d_wstrb(dmem_wstrb), .d_rdata(dmem_rdata), .d_ready(dmem_ready)
);

// Sticky flags: most directed tests assert these never fire, since a hand
// written program that trips either one has a bug in the *test*, not just
// a CPU behavior to characterize.
logic sticky_illegal, sticky_misaligned;
always_ff @(posedge clk) begin
  if (!reset_n) begin
    sticky_illegal    <= 1'b0;
    sticky_misaligned <= 1'b0;
  end else begin
    if (dbg_illegal)    sticky_illegal    <= 1'b1;
    if (dbg_misaligned) sticky_misaligned <= 1'b1;
  end
end

task automatic apply_reset;
  reset_n = 0;
  repeat (3) @(posedge clk);
  #1;
  reset_n = 1;
endtask

task automatic wait_for_halt(input integer max_cycles);
  logic [31:0] prev_pc;
  logic        prev_pc_valid;
  logic        halted;
  integer      cyc;
  begin
    prev_pc_valid = 1'b0;
    prev_pc       = 32'h0;
    halted        = 1'b0;
    cyc           = 0;
    while (!halted) begin
      @(posedge clk);
      #1;
      // Only compare *valid* retiring PCs. A pipelined core interleaves
      // bubbles into the retire stream (e.g. every taken branch/jump
      // flushes the 2 younger wrong-path fetches, which never reach WB
      // but still occupy a WB "slot" with valid=0) -- an invalid slot's
      // pc is not meaningful (it carries whatever a flushed bubble resets
      // to, not "no instruction retired this cycle"), so it must never be
      // compared against or overwrite prev_pc.
      if (trace.valid) begin
        if (prev_pc_valid && trace.pc === prev_pc) halted = 1'b1;
        else begin
          prev_pc       = trace.pc;
          prev_pc_valid = 1'b1;
        end
      end
      cyc = cyc + 1;
      if (cyc > max_cycles) begin
        $display("TESTBENCH_RESULT: FAIL (timeout: no halt loop after %0d cycles)", max_cycles);
        $finish;
      end
    end
  end
endtask

initial begin : global_watchdog
  #10_000_000;
  $display("TESTBENCH_RESULT: FAIL (global simulation timeout)");
  $finish;
end
