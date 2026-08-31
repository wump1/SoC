`timescale 1ns/1ps
module tb_hazard_unit;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic       id_ex_mem_read;
  logic [4:0] id_ex_rd;
  logic [4:0] if_id_rs1, if_id_rs2;
  logic       stall;

  hazard_unit dut (.*);

  task automatic run(input logic mem_read, input logic [4:0] rd,
                      input logic [4:0] rs1, input logic [4:0] rs2,
                      input logic expected, input string msg);
    id_ex_mem_read = mem_read; id_ex_rd = rd;
    if_id_rs1 = rs1; if_id_rs2 = rs2;
    #1;
    tb_check(stall === expected, $sformatf("%s: got %0d expected %0d", msg, stall, expected));
  endtask

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_hazard_unit]"); $finish;
  end

  initial begin
    run(1'b0, 5'd1, 5'd1, 5'd2, 1'b0, "not a load in EX -> never stalls");
    run(1'b1, 5'd1, 5'd1, 5'd2, 1'b1, "load-use on rs1");
    run(1'b1, 5'd2, 5'd1, 5'd2, 1'b1, "load-use on rs2");
    run(1'b1, 5'd3, 5'd1, 5'd2, 1'b0, "load in EX but no dependency -> no stall");
    run(1'b1, 5'd0, 5'd0, 5'd0, 1'b0, "load into x0 never stalls, even with matching rs fields");

    tb_summary("tb_hazard_unit");
  end
endmodule
