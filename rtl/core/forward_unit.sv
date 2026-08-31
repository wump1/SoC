`timescale 1ns/1ps
// EX-stage operand forwarding (Section 7.1). Selects, for each ALU source
// operand, between the value ID/EX latched from the register file and a
// newer result still in flight -- EX/MEM (an ALU result one cycle ahead,
// not yet architecturally committed) or MEM/WB (about to commit this
// cycle). EX/MEM wins when both match: it is the newer producer.
//
// x0 is excluded on the producer side (rd==0 never forwards, matching
// "writes to x0 have no architectural effect") and the consumer side
// (rs==0 always reads zero, so it never needs forwarding) is naturally
// safe too, since the ID/EX register value for x0 is already zero.
//
// This covers dependency distances of 1 (EX/MEM) and 2 (MEM/WB) cycles.
// Distance 3 -- a producer retiring in WB the same cycle a *different*,
// later instruction is reading that register in ID -- is handled
// separately, in rv32_core.sv, as a bypass feeding the ID/EX register's
// input directly; by the time such a producer would reach EX/MEM or
// MEM/WB here, it has already left the pipeline.
module forward_unit
  import rv32_pkg::*;
(
  input  logic [4:0] id_ex_rs1,
  input  logic [4:0] id_ex_rs2,

  input  logic       ex_mem_reg_write,
  input  logic [4:0] ex_mem_rd,

  input  logic       mem_wb_reg_write,
  input  logic [4:0] mem_wb_rd,

  output fwd_sel_e    forward_a,
  output fwd_sel_e    forward_b
);

  logic ex_mem_valid_producer, mem_wb_valid_producer;
  assign ex_mem_valid_producer = ex_mem_reg_write && (ex_mem_rd != 5'd0);
  assign mem_wb_valid_producer = mem_wb_reg_write && (mem_wb_rd != 5'd0);

  always_comb begin
    if (ex_mem_valid_producer && (ex_mem_rd == id_ex_rs1))
      forward_a = FWD_EX_MEM;
    else if (mem_wb_valid_producer && (mem_wb_rd == id_ex_rs1))
      forward_a = FWD_MEM_WB;
    else
      forward_a = FWD_NONE;
  end

  always_comb begin
    if (ex_mem_valid_producer && (ex_mem_rd == id_ex_rs2))
      forward_b = FWD_EX_MEM;
    else if (mem_wb_valid_producer && (mem_wb_rd == id_ex_rs2))
      forward_b = FWD_MEM_WB;
    else
      forward_b = FWD_NONE;
  end

endmodule : forward_unit
