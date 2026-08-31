`timescale 1ns/1ps
// 32x32 integer register file. x0 is hardwired to zero: never stored, never
// read back as anything but zero, and writes to it are discarded.
//
// Read-during-write semantics (Section 12.2 design decision): a read whose
// address matches the same-cycle write address combinationally observes the
// NEW (write) data, not the stale stored value. This "write-first" behavior
// is what lets the 5-stage pipeline's WB and ID stages touch the same
// register in the same cycle without a dedicated MEM/WB-to-ID forwarding
// path -- the forwarding unit only ever needs to cover EX/MEM and MEM/WB
// producers feeding the EX stage (Section 7.1).
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

  assign rdata1 = (raddr1 == 5'd0)                    ? 32'h0 :
                  (we && waddr != 5'd0 && waddr == raddr1) ? wdata :
                  regs[raddr1];

  assign rdata2 = (raddr2 == 5'd0)                    ? 32'h0 :
                  (we && waddr != 5'd0 && waddr == raddr2) ? wdata :
                  regs[raddr2];

endmodule : regfile
