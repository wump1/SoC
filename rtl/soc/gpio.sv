`timescale 1ns/1ps
// Memory-mapped GPIO output register (docs/memory_map.md: 0x20000004).
// Board-agnostic on purpose: this module knows nothing about which
// physical pin any bit drives, or how many LEDs exist -- that mapping
// belongs entirely in a board-specific top-level wrapper under
// fpga/boards/, never here (Section "BOARD-INDEPENDENT DESIGN RULE").
// Reset drives a deterministic known value (all zero).
module gpio #(
  parameter int unsigned WIDTH = 8
)(
  input  logic              clk,
  input  logic               reset_n,

  input  logic                we,
  input  logic [31:0]         wdata, // only wdata[WIDTH-1:0] is used; a store's upper bits are simply discarded

  output logic [WIDTH-1:0]    gpio_out
);

  always_ff @(posedge clk) begin
    if (!reset_n) gpio_out <= '0;
    else if (we)  gpio_out <= wdata[WIDTH-1:0];
  end

endmodule : gpio
