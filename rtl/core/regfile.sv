`timescale 1ns/1ps
// 32x32 integer register file. x0 is hardwired to zero: never stored, never
// read back as anything but zero, and writes to it are discarded.
//
// Read-during-write semantics (Section 12.2 design decision): plain
// synchronous write, no same-cycle bypass. A read of the address being
// written this same cycle observes the OLD stored value; the write lands
// on the clock edge and is visible starting next cycle. This is what real
// register-file hardware does (a read port shows the pre-edge value until
// the write edge actually happens) and is also what a *single-cycle* CPU
// architecturally wants: an instruction's ALU input must be its operand's
// value from *before* this instruction runs, even when that operand's
// register is also this same instruction's own rd (e.g. `addi x1,x1,1`).
//
// A same-cycle write-sees-read bypass was tried here first, aimed at the
// future pipeline's WB-vs-ID same-cycle hazard, and had to be removed: the
// regfile has no way to tell "the write is for an older instruction in WB
// while this read is a different, younger instruction in ID" (pipeline,
// where bypassing is correct) apart from "the write and read are the same
// currently-executing single-cycle instruction with rd==rs1" (where
// bypassing creates a real combinational cycle: rdata1 -> alu_a ->
// alu_result -> wdata -> rdata1). It hung an actual simulation run on
// `addi a5,a5,564` before being caught. The pipeline's MEM/WB-to-ID
// forwarding belongs in the pipeline datapath instead, as an explicit mux
// comparing ID's rs1/rs2 against the MEM/WB *pipeline register's* rd --
// structurally a different instruction, so it can never alias like this.
module regfile
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        reset_n,

  input  logic        we,
  input  logic [4:0]  waddr,
  input  logic [31:0] wdata,

  input  logic [4:0]  raddr1,
  input  logic [4:0]  raddr2,
  output logic [31:0] rdata1,
  output logic [31:0] rdata2
);

  logic [31:0] regs [1:31];

  integer i;
  always_ff @(posedge clk) begin
    if (!reset_n) begin
      for (i = 1; i < 32; i = i + 1) regs[i] <= 32'h0;
    end else if (we && waddr != 5'd0) begin
      regs[waddr] <= wdata;
    end
  end

  assign rdata1 = (raddr1 == 5'd0) ? 32'h0 : regs[raddr1];
  assign rdata2 = (raddr2 == 5'd0) ? 32'h0 : regs[raddr2];

endmodule : regfile
