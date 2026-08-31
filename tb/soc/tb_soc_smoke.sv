`timescale 1ns/1ps
// Runs sw/asm/loop.S (already verified against both bare cores) through
// the full SoC -- CPU -> address_decoder -> imem/dmem -- to prove the
// decoder correctly routes RAM traffic and doesn't disturb it versus the
// bare-core test. INIT_FILE is set via defparam on the nested imem/dmem
// instances directly (see soc_top.sv's header comment: Icarus can't
// relay a `parameter string` through soc_top's own parameter list).
module tb_soc_smoke;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  logic clk = 0;
  logic async_reset_n;
  logic [7:0] gpio_out;
  logic uart_tx_line;

  always #5 clk = ~clk;

  soc_top #(.GPIO_WIDTH(8)) dut (
    .clk, .async_reset_n,
    .gpio_out(gpio_out), .uart_tx(uart_tx_line)
  );

  defparam dut.u_imem.INIT_FILE = "build/programs/loop.imem.hex";
  defparam dut.u_dmem.INIT_FILE = "build/programs/loop.dmem.hex";

  task automatic apply_reset;
    async_reset_n = 0;
    repeat (3) @(posedge clk);
    #1;
    async_reset_n = 1;
  endtask

  task automatic wait_for_halt(input integer max_cycles);
    logic [31:0] prev_pc;
    logic        prev_pc_valid;
    logic        halted;
    integer      cyc;
    begin
      prev_pc_valid = 1'b0;
      prev_pc       = 32'h0;
      halted        = 1'b0;
      cyc           = 0;
      while (!halted) begin
        @(posedge clk);
        #1;
        if (dut.trace.valid) begin
          if (prev_pc_valid && dut.trace.pc === prev_pc) halted = 1'b1;
          else begin
            prev_pc       = dut.trace.pc;
            prev_pc_valid = 1'b1;
          end
        end
        cyc = cyc + 1;
        if (cyc > max_cycles) begin
          $display("TESTBENCH_RESULT: FAIL (timeout: no halt loop after %0d cycles)", max_cycles);
          $finish;
        end
      end
    end
  endtask

  initial begin
    apply_reset();
    wait_for_halt(2000);

    tb_check(dut.u_cpu.u_regfile.regs[1] === 32'd55, "sum(1..10) == 55 through the full SoC");
    tb_check(!(dut.u_cpu.dbg_illegal), "no illegal-instruction decode occurred");
    tb_check(!(dut.u_cpu.dbg_misaligned), "no misaligned access occurred");
    tb_check(gpio_out === 8'h00, "GPIO stayed at its reset value (never written by this program)");

    tb_summary("tb_soc_smoke");
  end
endmodule
