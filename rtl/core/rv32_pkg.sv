// RV32I shared types, opcodes, and control encodings.
// Single source of truth for every RTL module in this project (Section 10.1:
// enums/typedefs instead of magic constants).
package rv32_pkg;

  localparam logic [31:0] RESET_VECTOR = 32'h0000_0000;

  // ---------------------------------------------------------------------
  // Opcodes (instr[6:0])
  // ---------------------------------------------------------------------
  localparam logic [6:0] OPCODE_LUI     = 7'b0110111;
  localparam logic [6:0] OPCODE_AUIPC   = 7'b0010111;
  localparam logic [6:0] OPCODE_JAL     = 7'b1101111;
  localparam logic [6:0] OPCODE_JALR    = 7'b1100111;
  localparam logic [6:0] OPCODE_BRANCH  = 7'b1100011;
  localparam logic [6:0] OPCODE_LOAD    = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE   = 7'b0100011;
  localparam logic [6:0] OPCODE_OPIMM   = 7'b0010011;
  localparam logic [6:0] OPCODE_OP      = 7'b0110011;
  localparam logic [6:0] OPCODE_MISCMEM = 7'b0001111;
  localparam logic [6:0] OPCODE_SYSTEM  = 7'b1110011;

  // Branch funct3
  localparam logic [2:0] F3_BEQ  = 3'b000;
  localparam logic [2:0] F3_BNE  = 3'b001;
  localparam logic [2:0] F3_BLT  = 3'b100;
  localparam logic [2:0] F3_BGE  = 3'b101;
  localparam logic [2:0] F3_BLTU = 3'b110;
  localparam logic [2:0] F3_BGEU = 3'b111;

  // Load/store size funct3 (shared encoding between LOAD and STORE opcodes;
  // STORE only ever uses F3_B/F3_H/F3_W).
  localparam logic [2:0] F3_B  = 3'b000;
  localparam logic [2:0] F3_H  = 3'b001;
  localparam logic [2:0] F3_W  = 3'b010;
  localparam logic [2:0] F3_BU = 3'b100;
  localparam logic [2:0] F3_HU = 3'b101;

  // ---------------------------------------------------------------------
  // ALU control
  // ---------------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD   = 4'd0,
    ALU_SUB   = 4'd1,
    ALU_SLL   = 4'd2,
    ALU_SLT   = 4'd3,
    ALU_SLTU  = 4'd4,
    ALU_XOR   = 4'd5,
    ALU_SRL   = 4'd6,
    ALU_SRA   = 4'd7,
    ALU_OR    = 4'd8,
    ALU_AND   = 4'd9,
    ALU_PASSB = 4'd10
  } alu_op_e;

  // Immediate format select
  typedef enum logic [2:0] {
    IMM_I    = 3'd0,
    IMM_S    = 3'd1,
    IMM_B    = 3'd2,
    IMM_U    = 3'd3,
    IMM_J    = 3'd4,
    IMM_NONE = 3'd5
  } imm_sel_e;

  // Writeback source select
  typedef enum logic [1:0] {
    WB_ALU = 2'b00,
    WB_MEM = 2'b01,
    WB_PC4 = 2'b10
  } wb_sel_e;

  // Control bundle produced by the decoder in ID and carried only as far as
  // required (Section 6.1).
  typedef struct packed {
    logic       reg_write;
    logic       mem_read;
    logic       mem_write;
    logic       branch;
    logic       jump;      // JAL or JALR (unconditional redirect)
    logic       jalr;      // JALR specifically: target LSB must be cleared
                            // and ALU operand A is rs1, not PC
    logic       alu_src_imm; // ALU operand B: 1 = immediate, 0 = rs2
    logic       alu_src_pc;  // ALU operand A: 1 = PC, 0 = rs1
    alu_op_e    alu_op;
    wb_sel_e    wb_sel;
    imm_sel_e   imm_sel;
    logic [2:0] funct3;
    logic       illegal;
  } control_t;

  // Retired-instruction trace, emitted by both the single-cycle core (every
  // cycle) and the pipelined core (on WB commit). Common shape lets a
  // testbench diff the two as a reference-model comparison (Section 9).
  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] instr;
    logic        rd_we;
    logic [4:0]  rd;
    logic [31:0] rd_wdata;
    logic        mem_we;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
  } trace_t;

endpackage : rv32_pkg
