`timescale 1ns/1ps
// Load-use interlock (Section 7.2). A load's data is not available until
// MEM, so if the instruction right behind it in ID needs that same
// register, EX-stage forwarding alone (which only ever has an ALU result
// to offer, one cycle too early for a load) cannot resolve it -- the
// pipeline must stall one cycle instead: hold PC and IF/ID, and bubble
// ID/EX so the load's slot in EX/MEM is filled by a NOP rather than the
// dependent instruction running one cycle too soon.
//
// `if_id_rs1`/`if_id_rs2` are raw bit-slices of the instruction currently
// in IF/ID, not a real decode: an instruction whose rs1/rs2 field bits
// happen to alias id_ex_rd without architecturally reading a register
// (e.g. LUI) can trigger an unnecessary stall. That costs a cycle, never
// correctness (a real dependency is never missed), and is documented
// here rather than spending a second decoder on hazard detection alone.
module hazard_unit
  import rv32_pkg::*;
(
  input  logic       id_ex_mem_read,
  input  logic [4:0] id_ex_rd,

  input  logic [4:0] if_id_rs1,
  input  logic [4:0] if_id_rs2,

  output logic       stall
);

  assign stall = id_ex_mem_read && (id_ex_rd != 5'd0) &&
                 ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));

endmodule : hazard_unit
