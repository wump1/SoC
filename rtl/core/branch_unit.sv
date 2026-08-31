`timescale 1ns/1ps
// Branch condition evaluation for BEQ/BNE/BLT/BGE/BLTU/BGEU. Operates on
// raw register values (post-forwarding, in the pipelined core) -- it does
// not go through the ALU, so the ALU stays free to compute the branch
// target (PC + immB) in the same cycle.
module branch_unit
  import rv32_pkg::*;
(
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  input  logic [2:0]  funct3,
  output logic        taken
);

  always_comb begin
    unique case (funct3)
      F3_BEQ:  taken = (rs1_data == rs2_data);
      F3_BNE:  taken = (rs1_data != rs2_data);
      F3_BLT:  taken = ($signed(rs1_data) <  $signed(rs2_data));
      F3_BGE:  taken = ($signed(rs1_data) >= $signed(rs2_data));
      F3_BLTU: taken = (rs1_data <  rs2_data);
      F3_BGEU: taken = (rs1_data >= rs2_data);
      default: taken = 1'b0;
    endcase
  end

endmodule : branch_unit
