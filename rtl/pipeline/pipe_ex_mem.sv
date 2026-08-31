`timescale 1ns/1ps
// EX/MEM pipeline register. Always advances (reset aside): by the time a
// branch/jump redirect is known (resolved in EX, off ID/EX's contents),
// whatever is already latched into EX/MEM is strictly older and on the
// correct path (Section 7.4: "Taken redirect: ...older ops advance").
module pipe_ex_mem
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        reset_n,

  input  logic        valid_in,
  input  logic [31:0] pc_in,
  input  logic [31:0] instr_in,
  input  logic [31:0] pc4_in,
  input  logic [4:0]  rd_in,
  input  logic [31:0] alu_result_in,
  input  logic [31:0] store_data_in,
  input  ex_mem_ctrl_t ctrl_in,

  output logic        valid_out,
  output logic [31:0] pc_out,
  output logic [31:0] instr_out,
  output logic [31:0] pc4_out,
  output logic [4:0]  rd_out,
  output logic [31:0] alu_result_out,
  output logic [31:0] store_data_out,
  output ex_mem_ctrl_t ctrl_out
);

  always_ff @(posedge clk) begin
    if (!reset_n) begin
      valid_out      <= 1'b0;
      pc_out         <= 32'h0;
      instr_out      <= 32'h0;
      pc4_out        <= 32'h0;
      rd_out         <= 5'h0;
      alu_result_out <= 32'h0;
      store_data_out <= 32'h0;
      ctrl_out       <= '0;
    end else begin
      valid_out      <= valid_in;
      pc_out         <= pc_in;
      instr_out      <= instr_in;
      pc4_out        <= pc4_in;
      rd_out         <= rd_in;
      alu_result_out <= alu_result_in;
      store_data_out <= store_data_in;
      ctrl_out       <= ctrl_in;
    end
  end

endmodule : pipe_ex_mem
