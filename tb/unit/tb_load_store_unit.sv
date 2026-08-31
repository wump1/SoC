`timescale 1ns/1ps
module tb_load_store_unit;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic [1:0]  addr_lo;
  logic [2:0]  funct3;
  logic [31:0] store_data;
  logic [3:0]  wstrb;
  logic [31:0] wdata;
  logic [31:0] load_rdata;
  logic [31:0] load_data;
  logic        misaligned;

  load_store_unit dut (.*);

  task automatic run_store(input logic [1:0] al, input logic [2:0] f3,
                            input logic [31:0] sd,
                            input logic [3:0] exp_strb, input logic [31:0] exp_wdata,
                            input string msg);
    addr_lo = al; funct3 = f3; store_data = sd;
    #1;
    tb_check(wstrb === exp_strb, $sformatf("%s wstrb: got %04b expected %04b", msg, wstrb, exp_strb));
    tb_check(wdata === exp_wdata, $sformatf("%s wdata: got %08h expected %08h", msg, wdata, exp_wdata));
  endtask

  task automatic run_load(input logic [1:0] al, input logic [2:0] f3,
                           input logic [31:0] rd, input logic [31:0] expected,
                           input string msg);
    addr_lo = al; funct3 = f3; load_rdata = rd;
    #1;
    tb_check(load_data === expected, $sformatf("%s: got %08h expected %08h", msg, load_data, expected));
  endtask

  task automatic run_align(input logic [1:0] al, input logic [2:0] f3,
                            input logic expected, input string msg);
    addr_lo = al; funct3 = f3;
    #1;
    tb_check(misaligned === expected, $sformatf("%s: got %0d expected %0d", msg, misaligned, expected));
  endtask

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_load_store_unit]"); $finish;
  end

  initial begin
    // SB: byte replicated to all lanes, strobe picks the target lane
    run_store(2'b00, F3_B, 32'h000000AB, 4'b0001, 32'hABABABAB, "SB addr_lo=00");
    run_store(2'b01, F3_B, 32'h000000AB, 4'b0010, 32'hABABABAB, "SB addr_lo=01");
    run_store(2'b10, F3_B, 32'h000000AB, 4'b0100, 32'hABABABAB, "SB addr_lo=10");
    run_store(2'b11, F3_B, 32'h000000AB, 4'b1000, 32'hABABABAB, "SB addr_lo=11");

    // SH: halfword replicated to both halves, strobe picks upper/lower pair
    run_store(2'b00, F3_H, 32'h0000BEEF, 4'b0011, 32'hBEEFBEEF, "SH addr_lo=00");
    run_store(2'b10, F3_H, 32'h0000BEEF, 4'b1100, 32'hBEEFBEEF, "SH addr_lo=10");

    // SW: whole word, all lanes
    run_store(2'b00, F3_W, 32'hDEADBEEF, 4'b1111, 32'hDEADBEEF, "SW");

    // Loads: sign vs zero extension, byte lane selection from a fixed word
    run_load(2'b00, F3_B,  32'h81828384, 32'hFFFFFF84, "LB lane0 sign-extends (0x84 is negative)");
    run_load(2'b01, F3_B,  32'h81828384, 32'hFFFFFF83, "LB lane1 sign-extends");
    run_load(2'b10, F3_B,  32'h81828384, 32'hFFFFFF82, "LB lane2 sign-extends");
    run_load(2'b11, F3_B,  32'h81828384, 32'hFFFFFF81, "LB lane3 sign-extends");
    run_load(2'b00, F3_BU, 32'h81828384, 32'h00000084, "LBU lane0 zero-extends");
    run_load(2'b11, F3_BU, 32'h81828384, 32'h00000081, "LBU lane3 zero-extends");

    run_load(2'b00, F3_H,  32'h81828384, 32'hFFFF8384, "LH lower half sign-extends (0x8384 negative)");
    run_load(2'b10, F3_H,  32'h81828384, 32'hFFFF8182, "LH upper half sign-extends");
    run_load(2'b00, F3_HU, 32'h81828384, 32'h00008384, "LHU lower half zero-extends");
    run_load(2'b10, F3_HU, 32'h81828384, 32'h00008182, "LHU upper half zero-extends");

    run_load(2'b00, F3_H,  32'h00007FFF, 32'h00007FFF, "LH positive halfword stays positive");

    run_load(2'b00, F3_W,  32'hDEADBEEF, 32'hDEADBEEF, "LW passthrough");

    // Alignment: bytes never misaligned; half needs addr_lo[0]=0; word needs addr_lo=00
    run_align(2'b00, F3_B,  1'b0, "byte @0 aligned");
    run_align(2'b11, F3_B,  1'b0, "byte @3 aligned (bytes always aligned)");
    run_align(2'b00, F3_H,  1'b0, "half @0 aligned");
    run_align(2'b01, F3_H,  1'b1, "half @1 misaligned");
    run_align(2'b10, F3_H,  1'b0, "half @2 aligned");
    run_align(2'b11, F3_H,  1'b1, "half @3 misaligned");
    run_align(2'b00, F3_W,  1'b0, "word @0 aligned");
    run_align(2'b01, F3_W,  1'b1, "word @1 misaligned");
    run_align(2'b10, F3_W,  1'b1, "word @2 misaligned");
    run_align(2'b11, F3_W,  1'b1, "word @3 misaligned");

    tb_summary("tb_load_store_unit");
  end
endmodule
