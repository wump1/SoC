`timescale 1ns/1ps
// sw/baremetal/gpio_blink.c loops forever, so there is no halt to wait
// for: this watches gpio_out for a bounded number of cycles and checks
// it actually toggles (proving the C program, the GPIO peripheral, and
// the address decoder's write path all work together), rather than
// checking a final state.
module tb_gpio_blink;
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

  defparam dut.u_imem.INIT_FILE = "build/programs/gpio_blink.imem.hex";
  defparam dut.u_dmem.INIT_FILE = "build/programs/gpio_blink.dmem.hex";

  integer i;
  integer rising_edges;
  logic prev_bit0;

  initial begin
    async_reset_n = 0;
    repeat (3) @(posedge clk);
    #1;
    async_reset_n = 1;

    tb_check(gpio_out === 8'h00, "GPIO reads its deterministic reset value before software runs");

    prev_bit0    = 1'b0;
    rising_edges = 0;
    for (i = 0; i < 5000; i = i + 1) begin
      @(posedge clk);
      #1;
      if (gpio_out[0] === 1'b1 && prev_bit0 === 1'b0) rising_edges = rising_edges + 1;
      prev_bit0 = gpio_out[0];
    end

    tb_check(rising_edges >= 3, $sformatf("GPIO bit 0 toggled on (>=3 rising edges expected), got %0d", rising_edges));
    tb_check(!(dut.u_cpu.dbg_illegal), "no illegal-instruction decode occurred");
    tb_check(!(dut.u_cpu.dbg_misaligned), "no misaligned access occurred");

    tb_summary("tb_gpio_blink");
  end
endmodule
