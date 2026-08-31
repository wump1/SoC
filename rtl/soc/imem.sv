`timescale 1ns/1ps
// Synthesizable instruction ROM: byte-addressable storage (matching the
// byte-per-line $readmemh hex scripts/bin2hex.py produces, the same
// format tb/common/sram_model.sv uses for simulation-only testing), read
// out a full word at a time. Zero-wait-state (combinational read),
// matching the core boundary's baseline (Section 5) -- ready is tied
// high; a later wait-state-capable wrapper can replace this without
// touching the CPU.
//
// FPGA note (Section "FPGA MEMORY INITIALIZATION"): a $readmemh that
// works in Icarus does not by itself prove the target FPGA's block RAM
// gets initialized in the synthesized bitstream -- that depends on the
// synthesis tool's memory-inference support for initial content, and
// must be checked in the M9 synthesis log, not assumed from simulation
// passing.
//
// No clk: the read is combinational, so nothing here is ever clocked.
// `req` is kept unused rather than removed -- it is part of the CPU's
// imem_req/addr/rdata/ready boundary contract (Section 5), the same
// reason imem_ready/dmem_ready stay as unused inputs on the CPU itself;
// a future registered-read version (real BRAM inference may want one --
// see the FPGA note above) would need it to know when to actually latch.
module imem #(
  parameter int unsigned ADDR_WIDTH = 16, // bytes; 64KB per docs/memory_map.md
  parameter string       INIT_FILE  = ""
)(
  input  logic        req,
  input  logic [31:0] addr,
  output logic [31:0] rdata,
  output logic        ready
);

  localparam int unsigned SIZE = (1 << ADDR_WIDTH);
  logic [7:0] mem [0:SIZE-1];

  integer k;
  initial begin
    for (k = 0; k < SIZE; k = k + 1) mem[k] = 8'h00;
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end

  // addr's high bits (above ADDR_WIDTH) were already used by
  // address_decoder to select this region before req was asserted, and
  // the low 2 bits are a byte-within-word offset this module doesn't
  // need (a whole word is always read); only the middle bits matter here.
  wire [ADDR_WIDTH-1:0] word_addr = {addr[ADDR_WIDTH-1:2], 2'b00};

  assign ready = 1'b1;
  assign rdata = {mem[word_addr+3], mem[word_addr+2], mem[word_addr+1], mem[word_addr+0]};

endmodule : imem
