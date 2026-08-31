`timescale 1ns/1ps
// Program counter. Fully synchronous, active-low reset (Section 12.2 design
// decision: reset is synchronous so it never fights static timing closure
// on an FPGA). `en` is held low by the hazard unit during a load-use stall.
module pc
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        reset_n,
  input  logic        en,
  input  logic [31:0] pc_next,
  output logic [31:0] pc_q
);

  always_ff @(posedge clk) begin
    if (!reset_n) pc_q <= RESET_VECTOR;
    else if (en)  pc_q <= pc_next;
  end

endmodule : pc
