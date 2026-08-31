`timescale 1ns/1ps
// Opcode/funct3/funct7 decode into: raw instruction fields, a compact
// control_t bundle, and the immediate-format select. No side effects are
// generated for unsupported/illegal encodings -- every control bit in an
// illegal instruction's bundle is zero, so it cannot write a register,
// write memory, branch, or jump no matter what garbage lives in its rd/rs
// fields (Section 9.3: "no unintended side effects").
module decoder
  import rv32_pkg::*;
(
  input  logic [31:0] instr,

  output logic [6:0]  opcode,
  output logic [4:0]  rd,
  output logic [4:0]  rs1,
  output logic [4:0]  rs2,
  output logic [2:0]  funct3,
  output logic [6:0]  funct7,

  output control_t     ctrl
);

  assign opcode = instr[6:0];
  assign rd     = instr[11:7];
  assign funct3 = instr[14:12];
  assign rs1    = instr[19:15];
  assign rs2    = instr[24:20];
  assign funct7 = instr[31:25];

  logic funct7_alt; // instr[30]: SUB/SRA vs ADD/SRL, when it applies
  assign funct7_alt = instr[30];

  // ALU op for OP and OP-IMM instructions. For OP-IMM, instr[30] only
  // means "alternate function" for SLLI/SRLI/SRAI (funct3 001/101) --
  // for every other OP-IMM funct3 those instruction bits are part of the
  // immediate, not a sub-opcode, so ADDI etc. must not treat them as SUB.
  // Ternaries between two enum literals need an explicit cast under strict
  // SystemVerilog enum-assignment rules (flagged by Icarus under -Wall and
  // by Verilator); plain if/else with a direct enum-literal assignment on
  // each branch sidesteps that ambiguity entirely and reads just as well.
  alu_op_e rtype_alu_op;
  always_comb begin
    unique case (funct3)
      3'b000:  if (funct7_alt) rtype_alu_op = ALU_SUB; else rtype_alu_op = ALU_ADD;
      3'b001:  rtype_alu_op = ALU_SLL;
      3'b010:  rtype_alu_op = ALU_SLT;
      3'b011:  rtype_alu_op = ALU_SLTU;
      3'b100:  rtype_alu_op = ALU_XOR;
      3'b101:  if (funct7_alt) rtype_alu_op = ALU_SRA; else rtype_alu_op = ALU_SRL;
      3'b110:  rtype_alu_op = ALU_OR;
      3'b111:  rtype_alu_op = ALU_AND;
      default: rtype_alu_op = ALU_ADD;
    endcase
  end

  alu_op_e itype_alu_op;
  always_comb begin
    unique case (funct3)
      3'b000:  itype_alu_op = ALU_ADD;  // ADDI
      3'b010:  itype_alu_op = ALU_SLT;  // SLTI
      3'b011:  itype_alu_op = ALU_SLTU; // SLTIU
      3'b100:  itype_alu_op = ALU_XOR;  // XORI
      3'b110:  itype_alu_op = ALU_OR;   // ORI
      3'b111:  itype_alu_op = ALU_AND;  // ANDI
      3'b001:  itype_alu_op = ALU_SLL;  // SLLI
      3'b101:  if (funct7_alt) itype_alu_op = ALU_SRA; else itype_alu_op = ALU_SRL; // SRAI/SRLI
      default: itype_alu_op = ALU_ADD;
    endcase
  end

  always_comb begin
    // Defaults: no side effects, no redirect -- the safe "do nothing" state
    // that illegal/unsupported encodings fall through to.
    ctrl.reg_write   = 1'b0;
    ctrl.mem_read    = 1'b0;
    ctrl.mem_write   = 1'b0;
    ctrl.branch      = 1'b0;
    ctrl.jump        = 1'b0;
    ctrl.jalr        = 1'b0;
    ctrl.alu_src_imm = 1'b0;
    ctrl.alu_src_pc  = 1'b0;
    ctrl.alu_op      = ALU_ADD;
    ctrl.wb_sel      = WB_ALU;
    ctrl.imm_sel     = IMM_NONE;
    ctrl.funct3      = funct3;
    ctrl.illegal     = 1'b0;

    unique case (opcode)
      OPCODE_LUI: begin
        ctrl.reg_write   = 1'b1;
        ctrl.alu_src_imm = 1'b1;
        ctrl.alu_op      = ALU_PASSB;
        ctrl.wb_sel      = WB_ALU;
        ctrl.imm_sel     = IMM_U;
      end

      OPCODE_AUIPC: begin
        ctrl.reg_write   = 1'b1;
        ctrl.alu_src_imm = 1'b1;
        ctrl.alu_src_pc  = 1'b1;
        ctrl.alu_op      = ALU_ADD;
        ctrl.wb_sel      = WB_ALU;
        ctrl.imm_sel     = IMM_U;
      end

      OPCODE_JAL: begin
        ctrl.reg_write   = 1'b1;
        ctrl.jump        = 1'b1;
        ctrl.alu_src_imm = 1'b1;
        ctrl.alu_src_pc  = 1'b1;
        ctrl.alu_op      = ALU_ADD;
        ctrl.wb_sel      = WB_PC4;
        ctrl.imm_sel     = IMM_J;
      end

      OPCODE_JALR: begin
        ctrl.reg_write   = 1'b1;
        ctrl.jump        = 1'b1;
        ctrl.jalr        = 1'b1;
        ctrl.alu_src_imm = 1'b1;
        ctrl.alu_op      = ALU_ADD;
        ctrl.wb_sel      = WB_PC4;
        ctrl.imm_sel     = IMM_I;
      end

      OPCODE_BRANCH: begin
        ctrl.branch      = 1'b1;
        ctrl.alu_src_imm = 1'b1;
        ctrl.alu_src_pc  = 1'b1;
        ctrl.alu_op      = ALU_ADD;
        ctrl.imm_sel     = IMM_B;
      end

      // For LOAD/STORE/OP below, `illegal` is computed first and every
      // other field in the same arm is gated on it inline, so each arm is
      // fully self-contained instead of relying on a later pass over the
      // whole struct to patch up whatever an illegal sub-encoding left
      // behind.
      OPCODE_LOAD: begin
        // LB/LH/LW/LBU/LHU only; other funct3 values are illegal.
        ctrl.illegal     = !(funct3 == F3_B || funct3 == F3_H || funct3 == F3_W ||
                              funct3 == F3_BU || funct3 == F3_HU);
        ctrl.reg_write   = !ctrl.illegal;
        ctrl.mem_read    = !ctrl.illegal;
        ctrl.alu_src_imm = 1'b1;
        ctrl.alu_op      = ALU_ADD;
        if (ctrl.illegal) begin
          ctrl.wb_sel  = WB_ALU;
          ctrl.imm_sel = IMM_NONE;
        end else begin
          ctrl.wb_sel  = WB_MEM;
          ctrl.imm_sel = IMM_I;
        end
      end

      OPCODE_STORE: begin
        // SB/SH/SW only.
        ctrl.illegal     = !(funct3 == F3_B || funct3 == F3_H || funct3 == F3_W);
        ctrl.mem_write   = !ctrl.illegal;
        ctrl.alu_src_imm = 1'b1;
        ctrl.alu_op      = ALU_ADD;
        if (ctrl.illegal) ctrl.imm_sel = IMM_NONE;
        else              ctrl.imm_sel = IMM_S;
      end

      OPCODE_OPIMM: begin
        ctrl.reg_write   = 1'b1;
        ctrl.alu_src_imm = 1'b1;
        ctrl.alu_op      = itype_alu_op;
        ctrl.wb_sel      = WB_ALU;
        ctrl.imm_sel     = IMM_I;
      end

      OPCODE_OP: begin
        // funct7 must be 0000000 or 0100000 (only distinguishing ADD/SUB,
        // SRL/SRA); anything else is not a defined RV32I R-type encoding.
        ctrl.illegal   = (funct7 != 7'b0000000) && (funct7 != 7'b0100000);
        ctrl.reg_write = !ctrl.illegal;
        if (ctrl.illegal) ctrl.alu_op = ALU_ADD;
        else              ctrl.alu_op = rtype_alu_op;
        ctrl.wb_sel    = WB_ALU;
        ctrl.imm_sel   = IMM_NONE;
      end

      OPCODE_MISCMEM: begin
        // FENCE: no ordering is needed with a single in-order pipeline and
        // no caches, so it is architecturally a NOP (Section 4.1: baseline
        // may document simplified/unsupported SYSTEM-class behavior).
      end

      OPCODE_SYSTEM: begin
        // ECALL/EBREAK: legal encodings, deliberately implemented as NOPs
        // -- this core has no privileged trap machinery (Section 2.2
        // non-goal). Not marked illegal: they are valid instructions with
        // documented (no-op) behavior, not garbage encodings.
      end

      default: begin
        // Opcode matches no defined RV32I instruction class. reg_write,
        // mem_read, mem_write, branch, jump, and jalr all stay at the
        // safe defaults set before this case statement -- this arm only
        // needs to raise `illegal`.
        ctrl.illegal = 1'b1;
      end
    endcase
  end

endmodule : decoder
