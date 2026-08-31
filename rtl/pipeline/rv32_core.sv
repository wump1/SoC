`timescale 1ns/1ps
// Five-stage pipelined RV32I core: IF -> ID -> EX -> MEM -> WB, built from
// the exact same rtl/core/ blocks as rv32_single.sv (decoder, alu,
// imm_gen, regfile, branch_unit, load_store_unit) plus the pipeline
// registers and hazard/forwarding logic in rtl/pipeline/ and rtl/core/
// (hazard_unit, forward_unit). Sharing those blocks means the only place
// architectural behavior could diverge from the single-cycle core is this
// integration -- which is exactly what makes rv32_single a useful
// reference model for comparison (Section 9).
//
// Memory model: same zero-wait-state baseline as rv32_single (Section 5),
// carried straight through -- imem_ready/dmem_ready stay unused here too.
//
// Hazard handling summary (see hazard_unit.sv/forward_unit.sv for the
// per-module rationale):
//   - EX-stage forwarding covers dependency distance 1 (EX/MEM) and 2
//     (MEM/WB), feeding the ALU operand mux, the branch comparison, and
//     the store-data operand -- all three can need a not-yet-committed
//     value.
//   - A distance-3 dependency (producer retires in WB the same cycle a
//     different instruction reads that register in ID) is resolved right
//     at the regfile read, comparing ID's rs1/rs2 against MEM/WB's rd --
//     by design this can only ever compare *different* instructions
//     (unlike the single-cycle core's removed same-cycle bypass, which
//     could alias with its own rd and loop), so it is always safe here.
//   - Load-use (hazard_unit) stalls PC and IF/ID for one cycle and forces
//     a bubble into ID/EX, since a load's data isn't available until MEM --
//     forwarding has nothing to offer the instruction directly behind it.
//   - Branches/jumps resolve in EX and flush IF/ID and ID/EX the same
//     cycle (flush depth 2): those are the two younger instructions
//     fetched on the assumed-not-taken path before the redirect is known.
module rv32_core
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

  // Forward declarations of stage-crossing signals used before their
  // driving stage's section below: EX/MEM and MEM/WB register outputs are
  // needed by earlier stages (forwarding into EX, tier-0 bypass and
  // regfile write in ID), and EX's redirect decision is needed by IF.
  // Verilog resolves these by name regardless of declaration order; they
  // are grouped here so every stage's own section only *drives* its own
  // signals.
  ex_mem_ctrl_t ex_mem_ctrl;
  logic [4:0]   ex_mem_rd;
  logic [31:0]  ex_mem_alu_result;
  logic         ex_mem_valid;

  mem_wb_ctrl_t mem_wb_ctrl;
  logic [4:0]   mem_wb_rd;
  logic [31:0]  mem_wb_wb_data;
  logic         mem_wb_valid;

  logic         ex_redirect;
  logic [31:0]  ex_jump_target;
  logic         hazard_stall;

  // ======================================================================
  // IF
  // ======================================================================
  logic [31:0] pc_q, pc_next, pc4_if, instr_if;
  logic        pc_en;

  assign pc_en = !hazard_stall;

  pc u_pc (.clk, .reset_n, .en(pc_en), .pc_next(pc_next), .pc_q(pc_q));
  assign imem_req  = 1'b1;
  assign imem_addr = pc_q;
  assign instr_if  = imem_rdata;
  assign pc4_if    = pc_q + 32'd4;
  assign pc_next   = ex_redirect ? ex_jump_target : pc4_if;

  logic        if_id_en, if_id_flush;
  logic        if_id_valid;
  logic [31:0] if_id_pc, if_id_pc4, if_id_instr;

  assign if_id_en    = !hazard_stall;
  assign if_id_flush = ex_redirect;

  pipe_if_id u_if_id (
    .clk, .reset_n, .en(if_id_en), .flush(if_id_flush),
    .valid_in(1'b1), .pc_in(pc_q), .pc4_in(pc4_if), .instr_in(instr_if),
    .valid_out(if_id_valid), .pc_out(if_id_pc), .pc4_out(if_id_pc4), .instr_out(if_id_instr)
  );

  // ======================================================================
  // ID
  // ======================================================================
  logic [4:0]  id_rd, id_rs1, id_rs2;
  control_t    id_ctrl_full;
  logic [31:0] id_imm;
  logic [31:0] id_rs1_data_raw, id_rs2_data_raw;
  logic [31:0] id_rs1_data, id_rs2_data;

  decoder u_decoder (
    .instr(if_id_instr), .opcode(), .rd(id_rd), .rs1(id_rs1), .rs2(id_rs2),
    .funct3(), .funct7(), .ctrl(id_ctrl_full)
  );
  imm_gen u_imm_gen (.instr(if_id_instr), .imm_sel(id_ctrl_full.imm_sel), .imm(id_imm));

  regfile u_regfile (
    .clk, .reset_n,
    .we(mem_wb_valid && mem_wb_ctrl.reg_write), .waddr(mem_wb_rd), .wdata(mem_wb_wb_data),
    .raddr1(id_rs1), .raddr2(id_rs2), .rdata1(id_rs1_data_raw), .rdata2(id_rs2_data_raw)
  );

  // Tier-0 (distance-3) bypass -- see the forward_unit.sv header comment.
  logic tier0_hit_rs1, tier0_hit_rs2;
  assign tier0_hit_rs1 = mem_wb_valid && mem_wb_ctrl.reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_rs1);
  assign tier0_hit_rs2 = mem_wb_valid && mem_wb_ctrl.reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_rs2);
  assign id_rs1_data   = tier0_hit_rs1 ? mem_wb_wb_data : id_rs1_data_raw;
  assign id_rs2_data   = tier0_hit_rs2 ? mem_wb_wb_data : id_rs2_data_raw;

  id_ex_ctrl_t id_ex_ctrl_in;
  assign id_ex_ctrl_in.reg_write   = id_ctrl_full.reg_write;
  assign id_ex_ctrl_in.mem_read    = id_ctrl_full.mem_read;
  assign id_ex_ctrl_in.mem_write   = id_ctrl_full.mem_write;
  assign id_ex_ctrl_in.branch      = id_ctrl_full.branch;
  assign id_ex_ctrl_in.jump        = id_ctrl_full.jump;
  assign id_ex_ctrl_in.jalr        = id_ctrl_full.jalr;
  assign id_ex_ctrl_in.alu_src_imm = id_ctrl_full.alu_src_imm;
  assign id_ex_ctrl_in.alu_src_pc  = id_ctrl_full.alu_src_pc;
  assign id_ex_ctrl_in.alu_op      = id_ctrl_full.alu_op;
  assign id_ex_ctrl_in.wb_sel      = id_ctrl_full.wb_sel;
  assign id_ex_ctrl_in.funct3      = id_ctrl_full.funct3;
  assign id_ex_ctrl_in.illegal     = id_ctrl_full.illegal;

  logic        id_ex_valid;
  logic [31:0] id_ex_pc, id_ex_instr, id_ex_pc4;
  logic [31:0] id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
  logic [4:0]  id_ex_rd, id_ex_rs1, id_ex_rs2;
  id_ex_ctrl_t id_ex_ctrl;

  hazard_unit u_hazard (
    .id_ex_mem_read(id_ex_ctrl.mem_read), .id_ex_rd(id_ex_rd),
    .if_id_rs1(id_rs1), .if_id_rs2(id_rs2),
    .stall(hazard_stall)
  );

  logic id_ex_flush;
  assign id_ex_flush = hazard_stall || ex_redirect;

  pipe_id_ex u_id_ex (
    .clk, .reset_n, .flush(id_ex_flush),
    .valid_in(if_id_valid), .pc_in(if_id_pc), .instr_in(if_id_instr), .pc4_in(if_id_pc4),
    .rs1_data_in(id_rs1_data), .rs2_data_in(id_rs2_data), .imm_in(id_imm),
    .rd_in(id_rd), .rs1_in(id_rs1), .rs2_in(id_rs2), .ctrl_in(id_ex_ctrl_in),
    .valid_out(id_ex_valid), .pc_out(id_ex_pc), .instr_out(id_ex_instr), .pc4_out(id_ex_pc4),
    .rs1_data_out(id_ex_rs1_data), .rs2_data_out(id_ex_rs2_data), .imm_out(id_ex_imm),
    .rd_out(id_ex_rd), .rs1_out(id_ex_rs1), .rs2_out(id_ex_rs2), .ctrl_out(id_ex_ctrl)
  );

  // ======================================================================
  // EX
  // ======================================================================
  fwd_sel_e forward_a, forward_b;
  forward_unit u_forward (
    .id_ex_rs1(id_ex_rs1), .id_ex_rs2(id_ex_rs2),
    .ex_mem_reg_write(ex_mem_valid && ex_mem_ctrl.reg_write), .ex_mem_rd(ex_mem_rd),
    .mem_wb_reg_write(mem_wb_valid && mem_wb_ctrl.reg_write), .mem_wb_rd(mem_wb_rd),
    .forward_a(forward_a), .forward_b(forward_b)
  );

  logic [31:0] rs1_fwd, rs2_fwd;
  always_comb begin
    unique case (forward_a)
      FWD_EX_MEM: rs1_fwd = ex_mem_alu_result;
      FWD_MEM_WB: rs1_fwd = mem_wb_wb_data;
      default:    rs1_fwd = id_ex_rs1_data;
    endcase
  end
  always_comb begin
    unique case (forward_b)
      FWD_EX_MEM: rs2_fwd = ex_mem_alu_result;
      FWD_MEM_WB: rs2_fwd = mem_wb_wb_data;
      default:    rs2_fwd = id_ex_rs2_data;
    endcase
  end

  logic [31:0] alu_a, alu_b, alu_result;
  assign alu_a = id_ex_ctrl.alu_src_pc  ? id_ex_pc  : rs1_fwd;
  assign alu_b = id_ex_ctrl.alu_src_imm ? id_ex_imm : rs2_fwd;
  alu u_alu (.a(alu_a), .b(alu_b), .op(id_ex_ctrl.alu_op), .result(alu_result));

  logic branch_taken;
  branch_unit u_branch (.rs1_data(rs1_fwd), .rs2_data(rs2_fwd), .funct3(id_ex_ctrl.funct3), .taken(branch_taken));

  assign ex_redirect    = id_ex_valid && (id_ex_ctrl.jump || (id_ex_ctrl.branch && branch_taken));
  assign ex_jump_target = id_ex_ctrl.jalr ? {alu_result[31:1], 1'b0} : alu_result;

  ex_mem_ctrl_t ex_mem_ctrl_in;
  assign ex_mem_ctrl_in.reg_write = id_ex_ctrl.reg_write;
  assign ex_mem_ctrl_in.mem_read  = id_ex_ctrl.mem_read;
  assign ex_mem_ctrl_in.mem_write = id_ex_ctrl.mem_write;
  assign ex_mem_ctrl_in.wb_sel    = id_ex_ctrl.wb_sel;
  assign ex_mem_ctrl_in.funct3    = id_ex_ctrl.funct3;
  assign ex_mem_ctrl_in.illegal   = id_ex_ctrl.illegal;

  logic [31:0] ex_mem_pc, ex_mem_instr, ex_mem_pc4;
  logic [31:0] ex_mem_store_data;

  pipe_ex_mem u_ex_mem (
    .clk, .reset_n,
    .valid_in(id_ex_valid), .pc_in(id_ex_pc), .instr_in(id_ex_instr), .pc4_in(id_ex_pc4),
    .rd_in(id_ex_rd), .alu_result_in(alu_result), .store_data_in(rs2_fwd), .ctrl_in(ex_mem_ctrl_in),
    .valid_out(ex_mem_valid), .pc_out(ex_mem_pc), .instr_out(ex_mem_instr), .pc4_out(ex_mem_pc4),
    .rd_out(ex_mem_rd), .alu_result_out(ex_mem_alu_result), .store_data_out(ex_mem_store_data), .ctrl_out(ex_mem_ctrl)
  );

  // ======================================================================
  // MEM
  // ======================================================================
  assign dmem_req  = ex_mem_valid && (ex_mem_ctrl.mem_read || ex_mem_ctrl.mem_write);
  assign dmem_we   = ex_mem_valid && ex_mem_ctrl.mem_write;
  assign dmem_addr = ex_mem_alu_result;

  logic [31:0] mem_lsu_wdata, mem_lsu_load_data;
  logic [3:0]  mem_lsu_wstrb;
  logic        mem_lsu_misaligned_raw;

  load_store_unit u_lsu (
    .addr_lo(ex_mem_alu_result[1:0]), .funct3(ex_mem_ctrl.funct3),
    .store_data(ex_mem_store_data), .wstrb(mem_lsu_wstrb), .wdata(mem_lsu_wdata),
    .load_rdata(dmem_rdata), .load_data(mem_lsu_load_data),
    .misaligned(mem_lsu_misaligned_raw)
  );
  assign dmem_wdata = mem_lsu_wdata;
  assign dmem_wstrb = dmem_we ? mem_lsu_wstrb : 4'b0000;
  // See rv32_single.sv: load_store_unit runs unconditionally every cycle,
  // so `misaligned` is only meaningful when a memory access is actually
  // happening.
  assign dbg_misaligned = mem_lsu_misaligned_raw && dmem_req;

  logic [31:0] mem_wb_data_resolved;
  always_comb begin
    unique case (ex_mem_ctrl.wb_sel)
      WB_ALU:  mem_wb_data_resolved = ex_mem_alu_result;
      WB_MEM:  mem_wb_data_resolved = mem_lsu_load_data;
      WB_PC4:  mem_wb_data_resolved = ex_mem_pc4;
      default: mem_wb_data_resolved = ex_mem_alu_result;
    endcase
  end

  mem_wb_ctrl_t mem_wb_ctrl_in;
  assign mem_wb_ctrl_in.reg_write = ex_mem_ctrl.reg_write;
  assign mem_wb_ctrl_in.illegal   = ex_mem_ctrl.illegal;

  logic [31:0] mem_wb_pc, mem_wb_instr;
  logic        mem_wb_mem_we;
  logic [31:0] mem_wb_mem_addr, mem_wb_mem_wdata;
  logic [3:0]  mem_wb_mem_wstrb;

  pipe_mem_wb u_mem_wb (
    .clk, .reset_n,
    .valid_in(ex_mem_valid), .pc_in(ex_mem_pc), .instr_in(ex_mem_instr),
    .rd_in(ex_mem_rd), .wb_data_in(mem_wb_data_resolved), .ctrl_in(mem_wb_ctrl_in),
    .mem_we_in(dmem_we), .mem_addr_in(ex_mem_alu_result),
    .mem_wdata_in(dmem_wdata), .mem_wstrb_in(dmem_wstrb),
    .valid_out(mem_wb_valid), .pc_out(mem_wb_pc), .instr_out(mem_wb_instr),
    .rd_out(mem_wb_rd), .wb_data_out(mem_wb_wb_data), .ctrl_out(mem_wb_ctrl),
    .mem_we_out(mem_wb_mem_we), .mem_addr_out(mem_wb_mem_addr),
    .mem_wdata_out(mem_wb_mem_wdata), .mem_wstrb_out(mem_wb_mem_wstrb)
  );

  // ======================================================================
  // WB (regfile write port wired above, in ID's section)
  // ======================================================================
  assign dbg_illegal = mem_wb_valid && mem_wb_ctrl.illegal;

  assign trace.valid     = mem_wb_valid;
  assign trace.pc        = mem_wb_pc;
  assign trace.instr     = mem_wb_instr;
  assign trace.rd_we     = mem_wb_valid && mem_wb_ctrl.reg_write && (mem_wb_rd != 5'd0);
  assign trace.rd        = mem_wb_rd;
  assign trace.rd_wdata  = mem_wb_wb_data;
  assign trace.mem_we    = mem_wb_valid && mem_wb_mem_we;
  assign trace.mem_addr  = mem_wb_mem_addr;
  assign trace.mem_wdata = mem_wb_mem_wdata;
  assign trace.mem_wstrb = mem_wb_mem_wstrb;

  // ======================================================================
  // Safety assertions (Section 9.3 / "PIPELINE ASSERTIONS"). regfile's
  // .we and dmem_we are already gated by valid above; these are an
  // independent check on that gating, not a restatement of it -- if a
  // future edit weakens the gate, these catch the resulting violation
  // directly instead of it silently surfacing as a wrong architectural
  // result somewhere downstream.
  // ======================================================================
  always_ff @(posedge clk) begin
    if (reset_n) begin
      assert (!(!mem_wb_valid && mem_wb_ctrl.reg_write))
        else $error("[ASSERT] invalid MEM/WB entry asserted reg_write");
      assert (!(!ex_mem_valid && (ex_mem_ctrl.mem_read || ex_mem_ctrl.mem_write)))
        else $error("[ASSERT] invalid EX/MEM entry asserted a memory access");
      assert (pc_q[1:0] == 2'b00)
        else $error("[ASSERT] PC is not word-aligned: %08h", pc_q);
    end
  end

endmodule : rv32_core
