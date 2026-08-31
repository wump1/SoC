`timescale 1ns/1ps
// Behavioral test memory: two independent byte-addressable regions (an
// instruction ROM window and a data RAM window, matching the project's
// logical memory map in docs/memory_map.md), both zero-wait-state
// (combinational read). This is a simulation-only convenience used by core
// testbenches to exercise rv32_single/rv32_core standalone -- it is not
// the synthesizable SoC memory (that is rtl/soc/imem.sv / rtl/soc/dmem.sv,
// added at M8) and is not itself meant to be synthesized.
//
// *_INIT_FILE is expected in the byte-per-line $readmemh format
// scripts/bin2hex.py produces from an objcopy -O binary extraction, with
// its @<address> anchor matching *_BASE below.
module sram_model #(
  parameter logic [31:0] IMEM_BASE      = 32'h0000_0000,
  parameter int unsigned IMEM_SIZE      = 32'h0001_0000, // bytes
  parameter string       IMEM_INIT_FILE = "",

  parameter logic [31:0] DMEM_BASE      = 32'h1000_0000,
  parameter int unsigned DMEM_SIZE      = 32'h0001_0000, // bytes
  parameter string       DMEM_INIT_FILE = ""
)(
  input  logic        clk,

  input  logic        i_req,
  input  logic [31:0] i_addr,
  output logic [31:0] i_rdata,
  output logic        i_ready,

  input  logic        d_req,
  input  logic        d_we,
  input  logic [31:0] d_addr,
  input  logic [31:0] d_wdata,
  input  logic [3:0]  d_wstrb,
  output logic [31:0] d_rdata,
  output logic        d_ready
);

  logic [7:0] imem_arr [0:IMEM_SIZE-1];
  logic [7:0] dmem_arr [0:DMEM_SIZE-1];

  integer k;
  initial begin
    for (k = 0; k < IMEM_SIZE; k = k + 1) imem_arr[k] = 8'h00;
    for (k = 0; k < DMEM_SIZE; k = k + 1) dmem_arr[k] = 8'h00;
    if (IMEM_INIT_FILE != "") $readmemh(IMEM_INIT_FILE, imem_arr);
    if (DMEM_INIT_FILE != "") $readmemh(DMEM_INIT_FILE, dmem_arr);
  end

  // dmem_wstrb already picks out the individual byte lane(s) *within* a
  // word (load_store_unit computed it from addr_lo, Section 8), so the
  // byte offsets below must start from the word-aligned base of the
  // access, not from the exact unaligned address -- adding both would
  // double-count the low address bits (e.g. a byte access at ...101 would
  // resolve wstrb[1] against index ...101+1 instead of the intended
  // word-aligned ...100+1).
  wire [31:0] i_off      = i_addr - IMEM_BASE;
  wire [31:0] d_off      = d_addr - DMEM_BASE;
  wire [31:0] i_word_off = {i_off[31:2], 2'b00};
  wire [31:0] d_word_off = {d_off[31:2], 2'b00};

  assign i_ready = 1'b1;
  assign i_rdata = {imem_arr[i_word_off+3], imem_arr[i_word_off+2],
                     imem_arr[i_word_off+1], imem_arr[i_word_off+0]};

  assign d_ready = 1'b1;
  assign d_rdata = {dmem_arr[d_word_off+3], dmem_arr[d_word_off+2],
                     dmem_arr[d_word_off+1], dmem_arr[d_word_off+0]};

  always_ff @(posedge clk) begin
    if (d_req && d_we) begin
      if (d_wstrb[0]) dmem_arr[d_word_off+0] <= d_wdata[7:0];
      if (d_wstrb[1]) dmem_arr[d_word_off+1] <= d_wdata[15:8];
      if (d_wstrb[2]) dmem_arr[d_word_off+2] <= d_wdata[23:16];
      if (d_wstrb[3]) dmem_arr[d_word_off+3] <= d_wdata[31:24];
    end
  end

endmodule : sram_model
