`timescale 1ns/1ps
// Integer ALU: all RV32I R-type/I-type arithmetic, logic, comparison, and
// shift operations, plus a PASSB op used to route LUI's immediate straight
// to the writeback mux through the same datapath as everything else.
module alu
  import rv32_pkg::*;
(
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  alu_op_e      op,
  output logic [31:0] result
);

  // RV32 shift amounts use only the low 5 bits of the shift operand,
  // whether it came from rs2 (register shifts) or the I-immediate (shifts
  // by immediate -- imm[4:0] aliases instr[24:20], the shamt field).
  logic [4:0] shamt;
  assign shamt = b[4:0];

  always_comb begin
    unique case (op)
      ALU_ADD:   result = a + b;
      ALU_SUB:   result = a - b;
      ALU_SLL:   result = a << shamt;
      ALU_SLT:   result = {31'h0, ($signed(a) < $signed(b))};
      ALU_SLTU:  result = {31'h0, (a < b)};
      ALU_XOR:   result = a ^ b;
      ALU_SRL:   result = a >> shamt;
      ALU_SRA:   result = $signed(a) >>> shamt;
      ALU_OR:    result = a | b;
      ALU_AND:   result = a & b;
      ALU_PASSB: result = b;
      default:   result = 32'h0;
    endcase
  end

endmodule : alu
