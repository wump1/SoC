`timescale 1ns/1ps
module tb_forward_unit;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic [4:0] id_ex_rs1, id_ex_rs2;
  logic       ex_mem_reg_write;
  logic [4:0] ex_mem_rd;
  logic       mem_wb_reg_write;
  logic [4:0] mem_wb_rd;
  fwd_sel_e   forward_a, forward_b;

  forward_unit dut (.*);

  task automatic run(input logic [4:0] rs1, input logic [4:0] rs2,
                      input logic exm_we, input logic [4:0] exm_rd,
                      input logic mwb_we, input logic [4:0] mwb_rd,
                      input fwd_sel_e exp_a, input fwd_sel_e exp_b,
                      input string msg);
    id_ex_rs1 = rs1; id_ex_rs2 = rs2;
    ex_mem_reg_write = exm_we; ex_mem_rd = exm_rd;
    mem_wb_reg_write = mwb_we; mem_wb_rd = mwb_rd;
    #1;
    tb_check(forward_a === exp_a, $sformatf("%s: forward_a got %0d exp %0d", msg, forward_a, exp_a));
    tb_check(forward_b === exp_b, $sformatf("%s: forward_b got %0d exp %0d", msg, forward_b, exp_b));
  endtask

  initial begin
    #100000; $display("TESTBENCH_RESULT: FAIL (timeout) [tb_forward_unit]"); $finish;
  end

  initial begin
    // No producers at all -> no forwarding.
    run(5'd1, 5'd2, 1'b0, 5'd1, 1'b0, 5'd2, FWD_NONE, FWD_NONE, "no producers");

    // EX/MEM produces rs1 only.
    run(5'd3, 5'd7, 1'b1, 5'd3, 1'b0, 5'd0, FWD_EX_MEM, FWD_NONE, "EX/MEM matches rs1");

    // MEM/WB produces rs2 only.
    run(5'd7, 5'd3, 1'b0, 5'd0, 1'b1, 5'd3, FWD_NONE, FWD_MEM_WB, "MEM/WB matches rs2");

    // Both stages could match the same register: EX/MEM (newer) wins.
    run(5'd5, 5'd5, 1'b1, 5'd5, 1'b1, 5'd5, FWD_EX_MEM, FWD_EX_MEM, "EX/MEM priority over MEM/WB");

    // Producer with reg_write=0 must not forward even if rd matches.
    run(5'd9, 5'd9, 1'b0, 5'd9, 1'b1, 5'd9, FWD_MEM_WB, FWD_MEM_WB, "EX/MEM ignored when its reg_write=0");
    run(5'd9, 5'd9, 1'b1, 5'd9, 1'b0, 5'd9, FWD_EX_MEM, FWD_EX_MEM, "MEM/WB ignored when its reg_write=0");

    // rd==x0 never forwards even with reg_write=1.
    run(5'd0, 5'd0, 1'b1, 5'd0, 1'b1, 5'd0, FWD_NONE, FWD_NONE, "x0 producer never forwards");

    // Independent rs1/rs2 resolve independently.
    run(5'd2, 5'd4, 1'b1, 5'd2, 1'b1, 5'd4, FWD_EX_MEM, FWD_MEM_WB, "rs1 from EX/MEM, rs2 from MEM/WB simultaneously");

    tb_summary("tb_forward_unit");
  end
endmodule
