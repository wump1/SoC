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
// gets initialized in the synthesized bitstream. M9 confirmed Yosys's
// frontend does parse $readmemh with a literal (non-parameter) path and
// attach the content as a $mem_v2 INIT parameter (see the `ifdef
// SYNTHESIS branch below and docs/fpga.md) -- but whether nextpnr/
// IceStorm's iCE40 SPRAM mapping for this device preserves that INIT
// through to a real programmed bitstream is still unconfirmed; iCE40UP5K's
// 4x256x16 SPRAM primitives are commonly documented as having no init
// capability at all, unlike the smaller EBR/BRAM-style blocks on other
// iCE40 parts. Known limitation -- see docs/fpga.md.
//
// No clk: the read is combinational, so nothing here is ever clocked.
// `req` is kept unused rather than removed -- it is part of the CPU's
// imem_req/addr/rdata/ready boundary contract (Section 5), the same
// reason imem_ready/dmem_ready stay as unused inputs on the CPU itself;
// a future registered-read version (real BRAM inference may want one --
// see the FPGA note above) would need it to know when to actually latch.
module imem #(
  parameter int unsigned ADDR_WIDTH = 16 // bytes; 64KB per docs/memory_map.md
`ifndef SYNTHESIS
  // Simulation-only parameter (sets the $readmemh source below): Yosys
  // 0.33's frontend cannot parse a `string`-typed parameter declaration at
  // all, so it must not reach it -- `SYNTHESIS` is implicitly defined by
  // `read_verilog` (see the assertion guards in rv32_core.sv/rv32_single.sv
  // for the same idiom). soc_top never sets this parameter either way; it
  // is only ever driven by testbenches via `defparam` on the leaf instance
  // (Icarus can't relay `parameter string` through module hierarchy). FPGA
  // memory initialization needs a different, synthesis-tool-specific
  // mechanism and is a known limitation -- see the FPGA note above.
  ,
  parameter string       INIT_FILE  = ""
`endif
)(
  input  logic        req,
  input  logic [31:0] addr,
  output logic [31:0] rdata,
  output logic        ready
);

  localparam int unsigned SIZE = (1 << ADDR_WIDTH);
  logic [7:0] mem [0:SIZE-1];

`ifndef SYNTHESIS
  integer k;
  initial begin
    for (k = 0; k < SIZE; k = k + 1) mem[k] = 8'h00;
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end
`else
  // Loads one real, representative program (default: uart_hello -- loops,
  // branches, and MMIO stores; see docs/fpga.md) purely so this module's
  // resource numbers in the M9 synthesis report reflect genuine decoded
  // logic instead of an artifact of Yosys constant-folding an
  // uninitialized ROM's fixed, unchanging fetch stream down to nearly
  // nothing. Not a functional requirement of the CPU/SoC -- a real
  // bitstream would embed whatever program is actually wanted. Override
  // with `-D SYNTH_IMEM_INIT="path/to/other.imem.hex"` on the yosys/
  // `read_verilog` command line to substitute a different program; the
  // referenced .hex must already exist (`make program PROGRAM=...`)
  // before synthesis runs, and the path is resolved relative to the
  // working directory `yosys` is invoked from (the repo root), not
  // relative to this source file, matching $readmemh's usual convention.
`ifndef SYNTH_IMEM_INIT
`define SYNTH_IMEM_INIT "build/programs/uart_hello.imem.hex"
`endif
  initial $readmemh(`SYNTH_IMEM_INIT, mem);
`endif

  // addr's high bits (above ADDR_WIDTH) were already used by
  // address_decoder to select this region before req was asserted, and
  // the low 2 bits are a byte-within-word offset this module doesn't
  // need (a whole word is always read); only the middle bits matter here.
  wire [ADDR_WIDTH-1:0] word_addr = {addr[ADDR_WIDTH-1:2], 2'b00};

  assign ready = 1'b1;
  assign rdata = {mem[word_addr+3], mem[word_addr+2], mem[word_addr+1], mem[word_addr+0]};

endmodule : imem
