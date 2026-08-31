`timescale 1ns/1ps
// Single-cycle RV32I core: every instruction completes IF->ID->EX->MEM->WB
// within one clock. This is the M2/M3 bring-up target (Section 1: "Pipeline
// only after architectural behavior is proven") and doubles afterward as
// the golden reference model the pipelined core's retire trace is diffed
// against (Section 9, reference-model comparison) -- both cores share the
// exact same unit blocks (decoder, alu, imm_gen, regfile, branch_unit,
// load_store_unit) from rtl/core/, so this integration is the only place
// architectural behavior could diverge between them.
//
// Memory model for this milestone: imem/dmem are treated as zero-wait-state
// (combinational-read) per Section 5 ("imem_ready and dmem_ready may remain
// permanently asserted" for the first simulator) -- the whole point of
// single-cycle is that fetch, decode, execute, and memory access all
// settle within one clock edge. imem_ready/dmem_ready are therefore
// intentionally unused here; the ports exist so the boundary contract
// matches the pipelined core and a later wait-state-capable memory can be
// dropped in without changing this interface.
module rv32_single
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        reset_n,

  output logic        imem_req,
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,
  input  logic        imem_ready,

  output logic        dmem_req,
  output logic        dmem_we,
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_wstrb,
  input  logic [31:0] dmem_rdata,
  input  logic        dmem_ready,

  output trace_t       trace,
  output logic         dbg_illegal,
  output logic         dbg_misaligned
);

  // ---- IF ----
  logic [31:0] pc_q, pc_next, pc4, instr;

  pc u_pc (.clk, .reset_n, .en(1'b1), .pc_next(pc_next), .pc_q(pc_q));
  assign imem_req  = 1'b1;
  assign imem_addr = pc_q;
  assign instr     = imem_rdata;
  assign pc4       = pc_q + 32'd4;

  // ---- ID ----
  logic [4:0] rd, rs1, rs2;
  control_t   ctrl;
  logic [31:0] imm;
  logic [31:0] rs1_data, rs2_data;
  logic [31:0] wb_data;
  logic        reg_we;

  // opcode/funct3/funct7 are decoder outputs kept for standalone
  // debugging/unit testing (see tb_decoder.sv); the datapath only needs
  // rd/rs1/rs2 and the control_t bundle (which already carries funct3),
  // so those three are intentionally left unconnected here.
  decoder u_decoder (.instr, .opcode(), .rd, .rs1, .rs2, .funct3(), .funct7(), .ctrl);
  imm_gen u_imm_gen (.instr, .imm_sel(ctrl.imm_sel), .imm);

  assign reg_we = ctrl.reg_write;
  regfile u_regfile (
    .clk, .reset_n,
    .we(reg_we), .waddr(rd), .wdata(wb_data),
    .raddr1(rs1), .raddr2(rs2), .rdata1(rs1_data), .rdata2(rs2_data)
  );

  // ---- EX ----
  logic [31:0] alu_a, alu_b, alu_result;
  logic        branch_taken, redirect;
  logic [31:0] jump_target;

  assign alu_a = ctrl.alu_src_pc  ? pc_q : rs1_data;
  assign alu_b = ctrl.alu_src_imm ? imm  : rs2_data;
  alu u_alu (.a(alu_a), .b(alu_b), .op(ctrl.alu_op), .result(alu_result));

  branch_unit u_branch (.rs1_data, .rs2_data, .funct3(ctrl.funct3), .taken(branch_taken));

  assign redirect    = ctrl.jump || (ctrl.branch && branch_taken);
  // JAL's target (PC + immJ) is already even by construction; JALR's
  // (rs1 + immI) is not, and the ISA requires clearing the LSB explicitly.
  assign jump_target = ctrl.jalr ? {alu_result[31:1], 1'b0} : alu_result;
  assign pc_next      = redirect ? jump_target : pc4;

  // ---- MEM ----
  logic [31:0] lsu_wdata, lsu_load_data;
  logic [3:0]  lsu_wstrb;
  logic        lsu_misaligned_raw;

  assign dmem_req  = ctrl.mem_read || ctrl.mem_write;
  assign dmem_we   = ctrl.mem_write;
  assign dmem_addr = alu_result;
  load_store_unit u_lsu (
    .addr_lo(alu_result[1:0]), .funct3(ctrl.funct3),
    .store_data(rs2_data), .wstrb(lsu_wstrb), .wdata(lsu_wdata),
    .load_rdata(dmem_rdata), .load_data(lsu_load_data),
    .misaligned(lsu_misaligned_raw)
  );
  // load_store_unit runs combinationally every cycle regardless of
  // instruction class, using whatever ctrl.funct3/alu_result happen to be
  // -- for a non-memory instruction those bits are meaningless noise (an
  // ALU op's funct3 can numerically alias a load/store size encoding), so
  // `misaligned` must only be believed when a memory access is actually
  // happening this cycle.
  assign dbg_misaligned = lsu_misaligned_raw && (ctrl.mem_read || ctrl.mem_write);
  assign dmem_wdata = lsu_wdata;
  assign dmem_wstrb = ctrl.mem_write ? lsu_wstrb : 4'b0000;

  // ---- WB ----
  always_comb begin
    unique case (ctrl.wb_sel)
      WB_ALU:  wb_data = alu_result;
      WB_MEM:  wb_data = lsu_load_data;
      WB_PC4:  wb_data = pc4;
      default: wb_data = alu_result;
    endcase
  end

  assign dbg_illegal = ctrl.illegal;

  // ---- Architectural trace: every cycle retires exactly one instruction
  // (or a reset bubble) in the single-cycle core.
  assign trace.valid     = reset_n;
  assign trace.pc        = pc_q;
  assign trace.instr     = instr;
  assign trace.rd_we     = reg_we && (rd != 5'd0);
  assign trace.rd        = rd;
  assign trace.rd_wdata  = wb_data;
  assign trace.mem_we    = dmem_we;
  assign trace.mem_addr  = dmem_addr;
  assign trace.mem_wdata = dmem_wdata;
  assign trace.mem_wstrb = dmem_wstrb;

endmodule : rv32_single
