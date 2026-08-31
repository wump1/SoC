`timescale 1ns/1ps
// Byte/halfword/word store-lane preparation and load extraction, plus
// alignment checking. `addr_lo` is the low 2 bits of the effective byte
// address (rs1 + immediate); the rest of the address selects which memory
// word, and is not this module's concern.
//
// Store side: the raw store value is replicated across all four byte lanes
// and `wstrb` selects only the lane(s) that should actually be written --
// the memory only ever commits the strobed bytes, so the unselected lanes'
// content is irrelevant.
module load_store_unit
  import rv32_pkg::*;
(
  input  logic [1:0]  addr_lo,
  input  logic [2:0]  funct3,

  input  logic [31:0] store_data,
  output logic [3:0]  wstrb,
  output logic [31:0] wdata,

  input  logic [31:0] load_rdata,
  output logic [31:0] load_data,

  output logic         misaligned
);

  always_comb begin
    wdata = 32'h0;
    wstrb = 4'b0000;
    unique case (funct3)
      F3_B: begin
        wdata = {4{store_data[7:0]}};
        unique case (addr_lo)
          2'b00: wstrb = 4'b0001;
          2'b01: wstrb = 4'b0010;
          2'b10: wstrb = 4'b0100;
          2'b11: wstrb = 4'b1000;
        endcase
      end
      F3_H: begin
        wdata = {2{store_data[15:0]}};
        wstrb = addr_lo[1] ? 4'b1100 : 4'b0011;
      end
      F3_W: begin
        wdata = store_data;
        wstrb = 4'b1111;
      end
      default: begin
        wdata = 32'h0;
        wstrb = 4'b0000;
      end
    endcase
  end

  always_comb begin
    unique case (funct3)
      F3_B:
        unique case (addr_lo)
          2'b00: load_data = {{24{load_rdata[7]}},  load_rdata[7:0]};
          2'b01: load_data = {{24{load_rdata[15]}}, load_rdata[15:8]};
          2'b10: load_data = {{24{load_rdata[23]}}, load_rdata[23:16]};
          2'b11: load_data = {{24{load_rdata[31]}}, load_rdata[31:24]};
        endcase
      F3_BU:
        unique case (addr_lo)
          2'b00: load_data = {24'h0, load_rdata[7:0]};
          2'b01: load_data = {24'h0, load_rdata[15:8]};
          2'b10: load_data = {24'h0, load_rdata[23:16]};
          2'b11: load_data = {24'h0, load_rdata[31:24]};
        endcase
      F3_H:  load_data = addr_lo[1] ? {{16{load_rdata[31]}}, load_rdata[31:16]}
                                     : {{16{load_rdata[15]}}, load_rdata[15:0]};
      F3_HU: load_data = addr_lo[1] ? {16'h0, load_rdata[31:16]}
                                     : {16'h0, load_rdata[15:0]};
      F3_W:  load_data = load_rdata;
      default: load_data = 32'h0;
    endcase
  end

  // Baseline requires natural alignment (Section 8, "Misalignment
  // policy"); byte accesses are never misaligned.
  always_comb begin
    unique case (funct3)
      F3_H, F3_HU: misaligned = addr_lo[0];
      F3_W:        misaligned = (addr_lo != 2'b00);
      default:     misaligned = 1'b0;
    endcase
  end

endmodule : load_store_unit
