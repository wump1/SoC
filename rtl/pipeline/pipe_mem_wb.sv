`timescale 1ns/1ps
// MEM/WB pipeline register. Always advances (reset aside), for the same
// reason as EX/MEM: its contents are always older than any in-flight
// redirect decision.
module pipe_mem_wb
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        reset_n,

  input  logic        valid_in,
  input  logic [31:0] pc_in,
  input  logic [31:0] instr_in,
  input  logic [4:0]  rd_in,
  input  logic [31:0] wb_data_in,
  input  mem_wb_ctrl_t ctrl_in,
  input  logic         mem_we_in,
  input  logic [31:0]  mem_addr_in,
  input  logic [31:0]  mem_wdata_in,
  input  logic [3:0]   mem_wstrb_in,

  output logic        valid_out,
  output logic [31:0] pc_out,
  output logic [31:0] instr_out,
  output logic [4:0]  rd_out,
  output logic [31:0] wb_data_out,
  output mem_wb_ctrl_t ctrl_out,
  output logic         mem_we_out,
  output logic [31:0]  mem_addr_out,
  output logic [31:0]  mem_wdata_out,
  output logic [3:0]   mem_wstrb_out
);

  always_ff @(posedge clk) begin
    if (!reset_n) begin
      valid_out     <= 1'b0;
      pc_out        <= 32'h0;
      instr_out     <= 32'h0;
      rd_out        <= 5'h0;
      wb_data_out   <= 32'h0;
      ctrl_out      <= '0;
      mem_we_out    <= 1'b0;
      mem_addr_out  <= 32'h0;
      mem_wdata_out <= 32'h0;
      mem_wstrb_out <= 4'h0;
    end else begin
      valid_out     <= valid_in;
      pc_out        <= pc_in;
      instr_out     <= instr_in;
      rd_out        <= rd_in;
      wb_data_out   <= wb_data_in;
      ctrl_out      <= ctrl_in;
      mem_we_out    <= mem_we_in;
      mem_addr_out  <= mem_addr_in;
      mem_wdata_out <= mem_wdata_in;
      mem_wstrb_out <= mem_wstrb_in;
    end
  end

endmodule : pipe_mem_wb
