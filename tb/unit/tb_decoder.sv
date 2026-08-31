`timescale 1ns/1ps
// Golden opcode encodings below come from riscv64-unknown-elf-as
// (see tb/programs/golden/decoder_vectors.S), not hand-assembled hex, so a
// bit gets the same treatment as tb_imm_gen: the real toolchain is the
// authority on what a legal encoding looks like, this testbench only
// asserts what *this core* is supposed to do with it. Illegal/edge vectors
// are built with named-field concatenation instead of hand-computed hex.
module tb_decoder;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic [31:0] instr;
  logic [6:0]  opcode;
  logic [4:0]  rd, rs1, rs2;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  control_t    ctrl;

  decoder dut (.instr(instr), .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2),
               .funct3(funct3), .funct7(funct7), .ctrl(ctrl));

  task automatic run(
    input logic [31:0] instr_i, input string msg,
    input logic     exp_reg_write, input logic exp_mem_read, input logic exp_mem_write,
    input logic     exp_branch,    input logic exp_jump,     input logic exp_jalr,
    input alu_op_e  exp_alu_op,    input wb_sel_e exp_wb_sel, input logic exp_illegal
  );
    instr = instr_i;
    #1;
    tb_check(ctrl.reg_write === exp_reg_write, $sformatf("%s: reg_write got %0d exp %0d", msg, ctrl.reg_write, exp_reg_write));
    tb_check(ctrl.mem_read  === exp_mem_read,  $sformatf("%s: mem_read got %0d exp %0d", msg, ctrl.mem_read, exp_mem_read));
    tb_check(ctrl.mem_write === exp_mem_write, $sformatf("%s: mem_write got %0d exp %0d", msg, ctrl.mem_write, exp_mem_write));
    tb_check(ctrl.branch    === exp_branch,    $sformatf("%s: branch got %0d exp %0d", msg, ctrl.branch, exp_branch));
    tb_check(ctrl.jump      === exp_jump,      $sformatf("%s: jump got %0d exp %0d", msg, ctrl.jump, exp_jump));
    tb_check(ctrl.jalr      === exp_jalr,      $sformatf("%s: jalr got %0d exp %0d", msg, ctrl.jalr, exp_jalr));
    tb_check(ctrl.alu_op    === exp_alu_op,    $sformatf("%s: alu_op got %0d exp %0d", msg, ctrl.alu_op, exp_alu_op));
    tb_check(ctrl.wb_sel    === exp_wb_sel,    $sformatf("%s: wb_sel got %0d exp %0d", msg, ctrl.wb_sel, exp_wb_sel));
    tb_check(ctrl.illegal   === exp_illegal,   $sformatf("%s: illegal got %0d exp %0d", msg, ctrl.illegal, exp_illegal));
  endtask

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_decoder]"); $finish;
  end

  initial begin
    // -- I-type ALU (rd=ra=x1, rs1=sp=x2) --
    run(32'h7ff10093, "ADDI",  1,0,0, 0,0,0, ALU_ADD,  WB_ALU, 0);
    run(32'hfff17093, "ANDI",  1,0,0, 0,0,0, ALU_AND,  WB_ALU, 0);
    run(32'h0ff16093, "ORI",   1,0,0, 0,0,0, ALU_OR,   WB_ALU, 0);
    run(32'hf0014093, "XORI",  1,0,0, 0,0,0, ALU_XOR,  WB_ALU, 0);
    run(32'hffb12093, "SLTI",  1,0,0, 0,0,0, ALU_SLT,  WB_ALU, 0);
    run(32'h00513093, "SLTIU", 1,0,0, 0,0,0, ALU_SLTU, WB_ALU, 0);
    run(32'h00711093, "SLLI",  1,0,0, 0,0,0, ALU_SLL,  WB_ALU, 0);
    run(32'h00715093, "SRLI",  1,0,0, 0,0,0, ALU_SRL,  WB_ALU, 0);
    run(32'h40715093, "SRAI",  1,0,0, 0,0,0, ALU_SRA,  WB_ALU, 0);

    // Spot-check raw field extraction on ANDI (rd=x1, rs1=x2, funct3=111).
    instr = 32'hfff17093; #1;
    tb_check(rd === 5'd1, $sformatf("ANDI rd field, got %0d expected 1", rd));
    tb_check(rs1 === 5'd2, $sformatf("ANDI rs1 field, got %0d expected 2", rs1));
    tb_check(funct3 === 3'b111, $sformatf("ANDI funct3 field, got %03b expected 111", funct3));

    // -- R-type ALU (rd=ra, rs1=sp, rs2=gp) --
    run(32'h003100b3, "ADD",  1,0,0, 0,0,0, ALU_ADD,  WB_ALU, 0);
    run(32'h403100b3, "SUB",  1,0,0, 0,0,0, ALU_SUB,  WB_ALU, 0);
    run(32'h003170b3, "AND",  1,0,0, 0,0,0, ALU_AND,  WB_ALU, 0);
    run(32'h003160b3, "OR",   1,0,0, 0,0,0, ALU_OR,   WB_ALU, 0);
    run(32'h003140b3, "XOR",  1,0,0, 0,0,0, ALU_XOR,  WB_ALU, 0);
    run(32'h003110b3, "SLL",  1,0,0, 0,0,0, ALU_SLL,  WB_ALU, 0);
    run(32'h003150b3, "SRL",  1,0,0, 0,0,0, ALU_SRL,  WB_ALU, 0);
    run(32'h403150b3, "SRA",  1,0,0, 0,0,0, ALU_SRA,  WB_ALU, 0);
    run(32'h003120b3, "SLT",  1,0,0, 0,0,0, ALU_SLT,  WB_ALU, 0);
    run(32'h003130b3, "SLTU", 1,0,0, 0,0,0, ALU_SLTU, WB_ALU, 0);

    // -- Upper immediate / PC-relative --
    run(32'h000012b7, "LUI",   1,0,0, 0,0,0, ALU_PASSB, WB_ALU, 0);
    run(32'h00000317, "AUIPC", 1,0,0, 0,0,0, ALU_ADD,   WB_ALU, 0);
    instr = 32'h00000317; #1; // AUIPC
    tb_check(ctrl.alu_src_pc === 1'b1, "AUIPC uses PC as ALU operand A");
    tb_check(ctrl.alu_src_imm === 1'b1, "AUIPC uses immediate as ALU operand B");

    // -- Branch / jump --
    run(32'h00108463, "BEQ",  0,0,0, 1,0,0, ALU_ADD, WB_ALU, 0);
    run(32'h008003ef, "JAL",  1,0,0, 0,1,0, ALU_ADD, WB_PC4, 0);
    run(32'h00038067, "JALR", 1,0,0, 0,1,1, ALU_ADD, WB_PC4, 0);
    instr = 32'h00108463; #1; // BEQ
    tb_check(ctrl.alu_src_pc === 1'b1, "BEQ target uses PC as ALU operand A");

    // -- Loads (rd=ra, rs1=sp) --
    run(32'h00012083, "LW",  1,1,0, 0,0,0, ALU_ADD, WB_MEM, 0);
    run(32'h00010083, "LB",  1,1,0, 0,0,0, ALU_ADD, WB_MEM, 0);
    run(32'h00014083, "LBU", 1,1,0, 0,0,0, ALU_ADD, WB_MEM, 0);
    run(32'h00011083, "LH",  1,1,0, 0,0,0, ALU_ADD, WB_MEM, 0);
    run(32'h00015083, "LHU", 1,1,0, 0,0,0, ALU_ADD, WB_MEM, 0);

    // -- Stores: never write a register --
    run(32'h00112223, "SW", 0,0,1, 0,0,0, ALU_ADD, WB_ALU, 0);
    run(32'h00110023, "SB", 0,0,1, 0,0,0, ALU_ADD, WB_ALU, 0);
    run(32'h00111023, "SH", 0,0,1, 0,0,0, ALU_ADD, WB_ALU, 0);

    // -- FENCE/ECALL/EBREAK: legal encodings, documented as no-ops --
    run(32'h0ff0000f, "FENCE",  0,0,0, 0,0,0, ALU_ADD, WB_ALU, 0);
    run(32'h00000073, "ECALL",  0,0,0, 0,0,0, ALU_ADD, WB_ALU, 0);
    run(32'h00100073, "EBREAK", 0,0,0, 0,0,0, ALU_ADD, WB_ALU, 0);

    // -- Illegal encodings must produce zero side effects --
    run(32'h00000000, "all-zero word", 0,0,0, 0,0,0, ALU_ADD, WB_ALU, 1);

    // R-type with funct7=0000001 (this is RV32M's MUL encoding -- not
    // implemented, and must be flagged illegal, not silently misdecoded).
    run({7'b0000001, 5'd3, 5'd2, 3'b000, 5'd1, OPCODE_OP},
        "R-type funct7=0000001 (MUL, unsupported)", 0,0,0, 0,0,0, ALU_ADD, WB_ALU, 1);

    // LOAD/STORE with a funct3 that has no defined width (011 = would-be
    // 64-bit LD, not part of RV32I).
    run({12'h0, 5'd2, 3'b011, 5'd1, OPCODE_LOAD},
        "LOAD funct3=011 (undefined width)", 0,0,0, 0,0,0, ALU_ADD, WB_ALU, 1);
    run({7'h0, 5'd3, 5'd2, 3'b011, 5'h0, OPCODE_STORE},
        "STORE funct3=011 (undefined width)", 0,0,0, 0,0,0, ALU_ADD, WB_ALU, 1);

    tb_summary("tb_decoder");
  end
endmodule
