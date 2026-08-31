`timescale 1ns/1ps
// Routes the CPU's single dmem port to RAM or one of the MMIO peripherals
// by explicit address range/match (docs/memory_map.md). Each peripheral's
// own write-enable is gated on its own exact address decode, so an
// unmapped address drives every ram_we/uart_we/gpio_we to 0 -- an
// unmapped store is a true no-op, never a write to the wrong peripheral.
// Zero-wait-state (cpu_ready tied high), matching the core boundary
// baseline used throughout this project. Purely combinational -- no
// clk/reset_n, since there is no state here to clock or reset.
module address_decoder
  import rv32_pkg::*;
(
  // CPU-facing dmem port
  input  logic         cpu_req,
  input  logic          cpu_we,
  input  logic [31:0]   cpu_addr,
  input  logic [31:0]   cpu_wdata,
  input  logic [3:0]    cpu_wstrb,
  output logic [31:0]   cpu_rdata,
  output logic          cpu_ready,

  // RAM port
  output logic         ram_req,
  output logic          ram_we,
  output logic [31:0]   ram_addr,
  output logic [31:0]   ram_wdata,
  output logic [3:0]    ram_wstrb,
  input  logic [31:0]   ram_rdata,
  input  logic          ram_ready, // unused: zero-wait-state baseline, same as imem_ready/dmem_ready on the CPU itself

  // UART TX data register
  output logic         uart_we,
  output logic [7:0]    uart_wdata,
  input  logic          uart_busy,

  // GPIO output register
  output logic         gpio_we,
  output logic [31:0]   gpio_wdata,
  input  logic [31:0]   gpio_rdata
);

  localparam logic [31:0] RAM_BASE    = 32'h1000_0000;
  localparam logic [31:0] RAM_MASK    = 32'hFFFF_0000; // 64KB window
  localparam logic [31:0] UART_ADDR   = 32'h2000_0000;
  localparam logic [31:0] GPIO_ADDR   = 32'h2000_0004;
  localparam logic [31:0] STATUS_ADDR = 32'h2000_0008;

  wire sel_ram    = ((cpu_addr & RAM_MASK) == RAM_BASE);
  wire sel_uart   = (cpu_addr == UART_ADDR);
  wire sel_gpio   = (cpu_addr == GPIO_ADDR);
  wire sel_status = (cpu_addr == STATUS_ADDR);

  assign ram_req   = cpu_req && sel_ram;
  assign ram_we    = cpu_req && cpu_we && sel_ram;
  assign ram_addr  = cpu_addr;
  assign ram_wdata = cpu_wdata;
  assign ram_wstrb = cpu_wstrb;

  assign uart_we    = cpu_req && cpu_we && sel_uart;
  assign uart_wdata = cpu_wdata[7:0];

  assign gpio_we    = cpu_req && cpu_we && sel_gpio;
  assign gpio_wdata = cpu_wdata;

  // status[0] = UART busy; the rest is reserved (reads as 0).
  logic [31:0] status_rdata;
  assign status_rdata = {31'b0, uart_busy};

  always_comb begin
    if (sel_ram)         cpu_rdata = ram_rdata;
    else if (sel_gpio)   cpu_rdata = gpio_rdata;
    else if (sel_status) cpu_rdata = status_rdata;
    else                 cpu_rdata = 32'h0; // UART (write-only) / unmapped
  end

  assign cpu_ready = 1'b1;

endmodule : address_decoder
