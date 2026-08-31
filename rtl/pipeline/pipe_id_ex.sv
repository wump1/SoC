`timescale 1ns/1ps
// ID/EX pipeline register. No `en`/hold input: this design's only stall
// (load-use) always turns ID/EX's *next* contents into a bubble rather
// than holding its current ones (Section 7.2/7.4) -- the dependent
// instruction stays behind in IF/ID instead, waiting its turn. `flush`
// covers both that bubble insertion and a taken branch/jump discarding
// the instruction currently in ID (Section 7.3's 2-stage flush depth for
// a branch resolved in EX: IF/ID and ID/EX both flush the same cycle).
module pipe_id_ex
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        reset_n,
  input  logic        flush,

  input  logic        valid_in,
  input  logic [31:0] pc_in,
  input  logic [31:0] instr_in,
  input  logic [31:0] pc4_in,
  input  logic [31:0] rs1_data_in,
  input  logic [31:0] rs2_data_in,
  input  logic [31:0] imm_in,
  input  logic [4:0]  rd_in,
  input  logic [4:0]  rs1_in,
  input  logic [4:0]  rs2_in,
  input  id_ex_ctrl_t  ctrl_in,

  output logic        valid_out,
  output logic [31:0] pc_out,
  output logic [31:0] instr_out,
  output logic [31:0] pc4_out,
  output logic [31:0] rs1_data_out,
  output logic [31:0] rs2_data_out,
  output logic [31:0] imm_out,
  output logic [4:0]  rd_out,
  output logic [4:0]  rs1_out,
  output logic [4:0]  rs2_out,
  output id_ex_ctrl_t  ctrl_out
);

  always_ff @(posedge clk) begin
    if (!reset_n || flush) begin
      valid_out    <= 1'b0;
      pc_out       <= 32'h0;
      instr_out    <= 32'h0;
      pc4_out      <= 32'h0;
      rs1_data_out <= 32'h0;
      rs2_data_out <= 32'h0;
      imm_out      <= 32'h0;
      rd_out       <= 5'h0;
      rs1_out      <= 5'h0;
      rs2_out      <= 5'h0;
      ctrl_out     <= '0;
    end else begin
      valid_out    <= valid_in;
      pc_out       <= pc_in;
      instr_out    <= instr_in;
      pc4_out      <= pc4_in;
      rs1_data_out <= rs1_data_in;
      rs2_data_out <= rs2_data_in;
      imm_out      <= imm_in;
      rd_out       <= rd_in;
      rs1_out      <= rs1_in;
      rs2_out      <= rs2_in;
      ctrl_out     <= ctrl_in;
    end
  end

endmodule : pipe_id_ex
