`timescale 1ns/1ps
// Decodes the UART TX serial waveform bit-by-bit (start bit, 8 data bits
// LSB-first, stop bit) exactly as an external receiver would, rather than
// inspecting internal RTL state -- this is what actually proves the UART
// works end to end, not just that its FSM reached some internal state.
// CLK_HZ/BAUD are test-only values (small on purpose, for fast
// simulation); uart_tx.sv's own header explains why the real board
// frequency doesn't matter for functional correctness here.
module tb_uart_hello;
  import rv32_pkg::*;
  `include "../common/tb_util.svh"

  localparam int unsigned CLK_HZ = 120_000;
  localparam int unsigned BAUD   = 12_000;
  localparam int unsigned DIV    = CLK_HZ / BAUD; // = 10 clock cycles per bit

  logic clk = 0;
  logic async_reset_n;
  logic [7:0] gpio_out;
  logic uart_tx_line;

  always #5 clk = ~clk;

  soc_top #(.CLK_HZ(CLK_HZ), .UART_BAUD(BAUD), .GPIO_WIDTH(8)) dut (
    .clk, .async_reset_n,
    .gpio_out(gpio_out), .uart_tx(uart_tx_line)
  );

  defparam dut.u_imem.INIT_FILE = "build/programs/uart_hello.imem.hex";
  defparam dut.u_dmem.INIT_FILE = "build/programs/uart_hello.dmem.hex";

  task automatic apply_reset;
    async_reset_n = 0;
    repeat (3) @(posedge clk);
    #1;
    async_reset_n = 1;
  endtask

  // Samples once per bit period at (approximately) its center. Uses
  // explicit edge detection (prev-vs-current, sampled every clock) for
  // the start bit rather than a level-sensitive `wait` -- back-to-back
  // bytes can have little or no idle gap, so by the time this task is
  // called tx may *already* be low from the new start bit, and a plain
  // "wait until low" would silently resolve mid-bit instead of at its
  // true beginning, misaligning every sample after it.
  task automatic uart_rx_byte(output logic [7:0] data);
    integer i;
    logic prev_tx, found_edge;
    begin
      prev_tx    = 1'b1;
      found_edge = 1'b0;
      while (!found_edge) begin
        @(posedge clk);
        #1;
        if (prev_tx === 1'b1 && uart_tx_line === 1'b0) found_edge = 1'b1;
        prev_tx = uart_tx_line;
      end
      // The edge-detect cycle above already counts as the first cycle of
      // the start bit.
      repeat ((DIV / 2) - 1) @(posedge clk);
      #1;
      tb_check(uart_tx_line === 1'b0, "start bit sampled low");

      data = 8'h00;
      for (i = 0; i < 8; i = i + 1) begin
        repeat (DIV) @(posedge clk);
        #1;
        data[i] = uart_tx_line;
      end

      repeat (DIV) @(posedge clk);
      #1;
      tb_check(uart_tx_line === 1'b1, "stop bit sampled high");
    end
  endtask

  // Explicit byte literals rather than indexing a `string` localparam:
  // EXPECTED[i]-style string indexing did not return the characters it
  // should have under this Icarus build (confirmed separately from the
  // decoder itself: the decoder correctly read back "RV32I OK\r\n" byte
  // for byte once this was the actual comparison target).
  logic [7:0] expected [0:9];
  logic [7:0] rx_byte;
  integer i;

  initial begin
    expected[0] = "R"; expected[1] = "V"; expected[2] = "3"; expected[3] = "2";
    expected[4] = "I"; expected[5] = " "; expected[6] = "O"; expected[7] = "K";
    expected[8] = 8'h0D; expected[9] = 8'h0A;
  end

  initial begin
    #10_000_000; $display("TESTBENCH_RESULT: FAIL (global timeout)"); $finish;
  end

  initial begin
    apply_reset();
    tb_check(uart_tx_line === 1'b1, "TX line idles high before any transmission");

    for (i = 0; i < 10; i = i + 1) begin
      uart_rx_byte(rx_byte);
      tb_check(rx_byte === expected[i],
        $sformatf("byte %0d: got 0x%02h ('%c') expected 0x%02h ('%c')",
          i, rx_byte, rx_byte, expected[i], expected[i]));
    end

    tb_check(!(dut.u_cpu.dbg_illegal), "no illegal-instruction decode occurred");
    tb_check(!(dut.u_cpu.dbg_misaligned), "no misaligned access occurred");

    tb_summary("tb_uart_hello");
  end
endmodule
