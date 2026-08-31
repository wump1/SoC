`timescale 1ns/1ps
// IF/ID pipeline register. `en` holds the current contents (load-use
// stall: the dependent instruction stays parked here for one extra
// cycle); `flush` forces the next contents to invalid regardless of `en`
// (a taken branch/jump discards whatever was just fetched on the
// assumed-not-taken path). flush takes priority over en, matching
// Section 7.4's pipeline register semantics table.
module pipe_if_id
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        reset_n,
  input  logic        en,
  input  logic        flush,

  input  logic        valid_in,
  input  logic [31:0] pc_in,
  input  logic [31:0] pc4_in,
  input  logic [31:0] instr_in,

  output logic        valid_out,
  output logic [31:0] pc_out,
  output logic [31:0] pc4_out,
  output logic [31:0] instr_out
);

  always_ff @(posedge clk) begin
    if (!reset_n || flush) begin
      valid_out <= 1'b0;
      pc_out    <= 32'h0;
      pc4_out   <= 32'h0;
      instr_out <= 32'h0;
    end else if (en) begin
      valid_out <= valid_in;
      pc_out    <= pc_in;
      pc4_out   <= pc4_in;
      instr_out <= instr_in;
    end
    // else: en=0, no flush -- hold (stall).
  end

endmodule : pipe_if_id
