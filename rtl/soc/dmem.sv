`timescale 1ns/1ps
// Synthesizable data RAM: same byte-addressable storage/format as imem.sv,
// with byte-strobed synchronous writes. Zero-wait-state (combinational
// read, ready tied high), matching the core boundary's baseline.
module dmem #(
  parameter int unsigned ADDR_WIDTH = 16, // bytes; 64KB per docs/memory_map.md
  parameter string       INIT_FILE  = ""
)(
  input  logic        clk,

  input  logic        req,
  input  logic        we,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,
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

  // See imem.sv: addr's high bits were already consumed by
  // address_decoder's region select, and wstrb (not addr's low 2 bits)
  // picks the byte lane(s) within the word.
  wire [ADDR_WIDTH-1:0] word_addr = {addr[ADDR_WIDTH-1:2], 2'b00};

  assign ready = 1'b1;
  assign rdata = {mem[word_addr+3], mem[word_addr+2], mem[word_addr+1], mem[word_addr+0]};

  always_ff @(posedge clk) begin
    if (req && we) begin
      if (wstrb[0]) mem[word_addr+0] <= wdata[7:0];
      if (wstrb[1]) mem[word_addr+1] <= wdata[15:8];
      if (wstrb[2]) mem[word_addr+2] <= wdata[23:16];
      if (wstrb[3]) mem[word_addr+3] <= wdata[31:24];
    end
  end

endmodule : dmem
