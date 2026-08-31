`timescale 1ns/1ps
// Board-independent SoC: the pipelined CPU (rv32_core -- the final core
// per Section 6's module table) plus instruction ROM, data RAM, an
// address-decoded MMIO bus, GPIO, and UART TX. Knows nothing about any
// specific FPGA board: no pin names, no oscillator assumptions beyond the
// CLK_HZ parameter (a placeholder until a real board is confirmed, see
// uart_tx.sv), no programmer/toolchain specifics. A board-specific
// wrapper under fpga/boards/ is the only place that ever mentions a
// physical pin (Section "BOARD-INDEPENDENT DESIGN RULE").
// IMEM/DMEM_INIT_FILE are deliberately not parameters here: this Icarus
// 12.0 build cannot propagate a `parameter string` value through more
// than one level of module hierarchy (confirmed with a minimal
// repro -- relaying an outer module's own string parameter into an
// inner instance's parameter fails to elaborate at all, even via an
// intermediate localparam; plain `int` parameters relay just fine, so
// every other parameter below still does). A test that needs to load a
// specific program into u_imem/u_dmem reaches those instances directly
// with `defparam dut.u_imem.INIT_FILE = "...";` /
// `defparam dut.u_dmem.INIT_FILE = "...";` instead, which works because
// it targets the leaf module's own parameter, not a relayed one.
module soc_top #(
  parameter int unsigned CLK_HZ          = 12_000_000, // placeholder, see uart_tx.sv
  parameter int unsigned UART_BAUD       = 115_200,
  parameter int unsigned IMEM_ADDR_WIDTH = 16,
  parameter int unsigned DMEM_ADDR_WIDTH = 16,
  parameter int unsigned GPIO_WIDTH      = 8
)(
  input  logic                  clk,
  input  logic                  async_reset_n,

  output logic [GPIO_WIDTH-1:0] gpio_out,
  output logic                  uart_tx
);
  import rv32_pkg::*;

  logic reset_n;
  reset_sync u_reset_sync (.clk, .async_reset_n, .reset_n);

  logic        imem_req;
  logic [31:0] imem_addr, imem_rdata;
  logic        imem_ready;
  logic        dmem_req, dmem_we;
  logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
  logic [3:0]  dmem_wstrb;
  logic        dmem_ready;
  // trace/dbg_illegal/dbg_misaligned are debug/verification signals, not
  // part of the synthesized SoC's function -- a testbench reaches them by
  // hierarchical reference (e.g. dut.u_cpu.dbg_illegal), so they are
  // deliberately never wired to a soc_top port.
  trace_t      trace;
  logic        dbg_illegal, dbg_misaligned;

  rv32_core u_cpu (
    .clk, .reset_n,
    .imem_req, .imem_addr, .imem_rdata, .imem_ready,
    .dmem_req, .dmem_we, .dmem_addr, .dmem_wdata, .dmem_wstrb, .dmem_rdata, .dmem_ready,
    .trace, .dbg_illegal, .dbg_misaligned
  );

  imem #(.ADDR_WIDTH(IMEM_ADDR_WIDTH)) u_imem (
    .req(imem_req), .addr(imem_addr), .rdata(imem_rdata), .ready(imem_ready)
  );

  logic        ram_req, ram_we;
  logic [31:0] ram_addr, ram_wdata, ram_rdata;
  logic [3:0]  ram_wstrb;
  logic        ram_ready;

  logic        uart_we_i;
  logic [7:0]  uart_wdata_i;
  logic        uart_busy_i;

  logic        gpio_we_i;
  logic [31:0] gpio_wdata_i;
  logic [31:0] gpio_rdata_i;

  address_decoder u_addr_dec (
    .cpu_req(dmem_req), .cpu_we(dmem_we), .cpu_addr(dmem_addr),
    .cpu_wdata(dmem_wdata), .cpu_wstrb(dmem_wstrb),
    .cpu_rdata(dmem_rdata), .cpu_ready(dmem_ready),
    .ram_req, .ram_we, .ram_addr, .ram_wdata, .ram_wstrb, .ram_rdata, .ram_ready,
    .uart_we(uart_we_i), .uart_wdata(uart_wdata_i), .uart_busy(uart_busy_i),
    .gpio_we(gpio_we_i), .gpio_wdata(gpio_wdata_i), .gpio_rdata(gpio_rdata_i)
  );

  dmem #(.ADDR_WIDTH(DMEM_ADDR_WIDTH)) u_dmem (
    .clk, .req(ram_req), .we(ram_we), .addr(ram_addr), .wdata(ram_wdata), .wstrb(ram_wstrb),
    .rdata(ram_rdata), .ready(ram_ready)
  );

  uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(UART_BAUD)) u_uart (
    .clk, .reset_n, .we(uart_we_i), .wdata(uart_wdata_i), .busy(uart_busy_i), .tx(uart_tx)
  );

  gpio #(.WIDTH(GPIO_WIDTH)) u_gpio (
    .clk, .reset_n, .we(gpio_we_i), .wdata(gpio_wdata_i), .gpio_out(gpio_out)
  );
  assign gpio_rdata_i = {{(32 - GPIO_WIDTH){1'b0}}, gpio_out};

endmodule : soc_top
