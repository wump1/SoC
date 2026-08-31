# M10: Physical Bring-Up (Board-Independent Procedure)

**None of the stages below have been executed.** This session runs in an
ephemeral cloud sandbox with no USB or hardware access -- there is no
physical FPGA, programmer, or serial adapter reachable from here, and
nothing in this repository claims otherwise. This document is a procedure
for the user to run on their own machine once real hardware is in hand; it
exists so bring-up has a concrete, staged plan rather than being an
undocumented gap.

**No board has been confirmed yet either** (see `docs/fpga.md`). Stage H0
below is a hard gate: nothing past it may proceed until the user confirms
the exact board model/revision, and every pin/oscillator/programmer fact
in this document must come from that board's own official documentation or
schematic, never guessed. This document intentionally does not itself
contain any pin numbers, oscillator frequency, or programmer command for
that reason -- those belong only in a board-specific wrapper under
`fpga/boards/<board>/` once H0 is satisfied, and only there.

## H0 -- Confirm the board, gather real facts

1. Confirm the exact board model and revision in hand (the working
   assumption has been iCEBreaker V1.1a, Lattice iCE40UP5K -- confirm this
   is still correct, or update it).
2. From that board's official schematic/pinout documentation (not memory,
   not a guess, not a similar-sounding board's docs), record: the
   oscillator frequency actually populated on the board, the pin names for
   the on-board LED(s), the reset button/pin if present, the UART TX/RX
   pins (and whether they route through an on-board USB-UART bridge or
   need an external adapter), and any PMOD pin assignments intended for
   use.
3. Only after this is written down from a primary source does a
   board-specific `.pcf` and `fpga/boards/<board>/` wrapper get created.
   Nothing upstream of this repository's board-independent RTL changes.

## H1 -- Toolchain and programmer connectivity

Confirm the local machine (the user's, not this sandbox) can see the
board at all, with no bitstream involved yet:

1. Install/confirm `yosys`, `nextpnr-ice40`, `icestorm` (`icepack`/
   `icetime`), and `openFPGALoader` (or the board-appropriate programmer)
   are on `PATH`. `scripts/check_tools.sh` covers the simulation/software
   toolchain but not these FPGA tools; extend it if useful.
2. Connect the board over USB and confirm the programmer detects it
   (e.g. `openFPGALoader --detect`, or the equivalent for whatever
   programmer the confirmed board actually uses per H0).
3. Do not proceed to H2 until this succeeds -- a bring-up failure at H2+
   is far harder to diagnose if basic connectivity was never confirmed
   first.

## H2 -- Minimal bitstream: one LED

The smallest possible end-to-end test of the whole chain (RTL -> synthesis
-> place-and-route -> bitstream -> programmer -> visible hardware effect),
deliberately with no CPU involved yet:

1. Write a trivial board-specific top-level module under
   `fpga/boards/<board>/` that drives one on-board LED from a simple
   counter off the real, confirmed oscillator pin -- this is the first
   file in the entire repository allowed to reference an actual pin name,
   and only after H0.
2. Write the matching `.pcf` from the H0 facts.
3. `yosys`/`nextpnr-ice40 --up5k --package <real package> --pcf <real
   pcf>`/`icepack`, then program it and confirm the LED actually blinks at
   the expected rate. This validates the full physical chain before the
   CPU is anywhere in the picture, so a failure here is unambiguously a
   board/toolchain/pin problem, not an RTL one.

## H3 -- UART bring-up

1. Extend the H2 board wrapper to instantiate `soc_top` (still with the
   downsized-memory configuration from `docs/fpga.md`'s smoke test, or
   smaller, until H4's memory question is resolved) with `uart_tx` wired
   to the board's real, confirmed UART TX pin.
2. Program `sw/asm/uart_hello.S` (already verified in simulation --
   `tb/soc/tb_uart_hello.sv`) and confirm the expected ASCII string
   actually arrives on a real terminal at the configured baud rate. This
   is the first stage that validates the SoC's behavior against real
   silicon rather than a simulator.

## H4 -- Full memory map

`docs/fpga.md` documents that the real 64 KiB instruction/data memory map
does not currently map to real block RAM/SPRAM at all (the CPU's
zero-wait-state, combinational-read memory boundary is fundamentally
incompatible with iCE40's synchronous-read-only memory primitives). This
stage is blocked on that redesign -- registering `imem`/`dmem`'s read port
and extending the hazard unit with a real memory-wait stall, using the
already-present `imem_ready`/`dmem_ready` ports -- being done and
re-verified against the full regression suite first. Do not attempt to
force the current combinational-read design into real BRAM/SPRAM; the
Yosys logs in `docs/fpga.md` show exactly why that doesn't work.

## H5 -- GPIO bring-up

Wire `gpio_out` to the board's real LED(s) (beyond H2's single test LED,
if more are available) and confirm `sw/baremetal/gpio_blink.c` (already
verified in simulation -- `tb/soc/tb_gpio_blink.sv`) produces the expected
visible blink pattern on real hardware.

## H6 -- Hardware regression pass

Run every program already covered by `tb/core/` and `tb/soc/` on real
hardware (to whatever extent each has an externally observable effect --
UART output and GPIO state are directly observable; ALU/branch/hazard
programs would need either a UART-based result dump added to each, or a
debug/JTAG readback path this project does not currently have) and confirm
hardware behavior matches the simulated `trace_t`/expected output exactly.
Any mismatch here is a real simulation-vs-hardware discrepancy and should
be root-caused with the same rigor as every simulation-only bug documented
throughout this project -- never dismissed as "probably just hardware
weirdness."
