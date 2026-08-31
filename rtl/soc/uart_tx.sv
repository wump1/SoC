`timescale 1ns/1ps
// Minimal transmit-only UART: 8 data bits, no parity, 1 stop bit, idle
// high. `busy` is the software-visible readiness signal (docs/memory_map.md
// status register bit 0) -- back-to-back stores never silently drop a
// byte because a write while busy is simply ignored by this module;
// software is expected to poll busy before writing the next byte.
//
// CLK_HZ is a PLACEHOLDER (Section "CLOCKING": the physical board's
// oscillator frequency is not yet confirmed) -- functional simulation
// only cares about the cycle-relative protocol (start bit, 8 data bits
// LSB-first, stop bit), not real-world baud accuracy, so any CLK_HZ
// value exercises the same logic. This must be set to the real,
// board-confirmed clock before physical bring-up; see docs/fpga.md.
module uart_tx #(
  parameter int unsigned CLK_HZ = 12_000_000,
  parameter int unsigned BAUD   = 115_200
)(
  input  logic       clk,
  input  logic        reset_n,

  input  logic         we,
  input  logic [7:0]   wdata,
  output logic          busy,

  output logic           tx
);

  localparam int unsigned DIV      = CLK_HZ / BAUD;
  localparam int unsigned DIV_BITS = (DIV <= 1) ? 1 : $clog2(DIV);

  typedef enum logic [1:0] {ST_IDLE, ST_START, ST_DATA, ST_STOP} state_e;
  state_e state;

  logic [DIV_BITS-1:0] baud_cnt;
  logic [2:0]          bit_idx;
  logic [7:0]           shift_reg;

  assign busy = (state != ST_IDLE);

  wire baud_tick = (baud_cnt == DIV_BITS'(DIV - 1));

  always_ff @(posedge clk) begin
    if (!reset_n) begin
      state     <= ST_IDLE;
      tx        <= 1'b1;
      baud_cnt  <= '0;
      bit_idx   <= '0;
      shift_reg <= '0;
    end else begin
      unique case (state)
        ST_IDLE: begin
          tx <= 1'b1;
          if (we) begin
            shift_reg <= wdata;
            baud_cnt  <= '0;
            state     <= ST_START;
          end
        end

        ST_START: begin
          tx <= 1'b0;
          if (baud_tick) begin
            baud_cnt <= '0;
            bit_idx  <= '0;
            state    <= ST_DATA;
          end else begin
            baud_cnt <= baud_cnt + 1'b1;
          end
        end

        ST_DATA: begin
          tx <= shift_reg[0];
          if (baud_tick) begin
            baud_cnt  <= '0;
            shift_reg <= {1'b0, shift_reg[7:1]};
            if (bit_idx == 3'd7) state <= ST_STOP;
            else                 bit_idx <= bit_idx + 1'b1;
          end else begin
            baud_cnt <= baud_cnt + 1'b1;
          end
        end

        ST_STOP: begin
          tx <= 1'b1;
          if (baud_tick) begin
            baud_cnt <= '0;
            state    <= ST_IDLE;
          end else begin
            baud_cnt <= baud_cnt + 1'b1;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule : uart_tx
