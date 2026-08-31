`timescale 1ns/1ps
// Two-flop synchronizer for an external, physically-asynchronous reset
// (a pushbutton, a power-on-reset IC) into a clean synchronous reset for
// the rest of the design. Assertion is immediate (asynchronous set on
// the flops themselves) since reset must take effect even without a
// clock edge; de-assertion is synchronized through two stages so a
// button release at an arbitrary instant relative to clk can never leave
// internal state metastable (Section "RESET DESIGN").
module reset_sync (
  input  logic clk,
  input  logic async_reset_n,
  output logic reset_n
);

  logic meta;

  always_ff @(posedge clk or negedge async_reset_n) begin
    if (!async_reset_n) begin
      meta    <= 1'b0;
      reset_n <= 1'b0;
    end else begin
      meta    <= 1'b1;
      reset_n <= meta;
    end
  end

endmodule : reset_sync
