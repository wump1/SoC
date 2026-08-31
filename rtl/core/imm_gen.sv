`timescale 1ns/1ps
// Immediate reconstruction and sign extension for I/S/B/U/J formats.
// Bit ordering follows the RV32I encoding exactly (Section 4.3) -- this is
// the module most likely to hide a branch-only or jump-only bug if a bit
// range is transposed, so every field below is commented with its source.
module imm_gen
  import rv32_pkg::*;
(
  input  logic [31:0] instr,
  input  imm_sel_e     imm_sel,
  output logic [31:0] imm
);

  always_comb begin
    unique case (imm_sel)
      // imm[11:0] = instr[31:20]
      IMM_I: imm = {{20{instr[31]}}, instr[31:20]};

      // imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
      IMM_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

      // imm[12]=instr[31], imm[11]=instr[7], imm[10:5]=instr[30:25],
      // imm[4:1]=instr[11:8], imm[0]=0
      IMM_B: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25],
                    instr[11:8], 1'b0};

      // imm[31:12] = instr[31:12], imm[11:0] = 0
      IMM_U: imm = {instr[31:12], 12'h0};

      // imm[20]=instr[31], imm[19:12]=instr[19:12], imm[11]=instr[20],
      // imm[10:1]=instr[30:21], imm[0]=0
      IMM_J: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20],
                    instr[30:21], 1'b0};

      default: imm = 32'h0; // IMM_NONE: e.g. R-type, never selected as ALU src
    endcase
  end

endmodule : imm_gen
