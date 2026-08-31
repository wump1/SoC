# FPGA: Synthesis, Place-and-Route, and Board Independence

## Board-independence rule

**No FPGA board has been confirmed for this project yet.** The intended
target is an iCEBreaker (Lattice iCE40UP5K), but the board has not been
purchased, and its exact model/revision has not been confirmed. Per the
project's standing constraint, nothing in this repository invents or
guesses a pin assignment, an oscillator frequency, a programmer
configuration, or any other board-specific fact:

- All CPU/SoC RTL (`rtl/`) is entirely board-independent: no pin names, no
  board-specific timing assumptions. `soc_top.sv`'s `CLK_HZ` parameter is a
  placeholder (default 12 MHz) used only to compute the UART baud divider
  in simulation -- it is not a claim about any real oscillator.
- **No `.pcf` pin-constraint file exists anywhere in this repository**, and
  none will be created until the exact board is confirmed.
- `fpga/boards/` is reserved for a future board-specific top-level wrapper
  and its `.pcf` -- empty until that happens.
- `make fpga-program` deliberately refuses to run (see below) rather than
  attempt anything.
- Physical bring-up (the staged H0-H6 procedure) is documented in
  `docs/bringup.md` as a procedure for the user to run on real hardware --
  this sandbox has no USB/hardware access and this project never claims to
  have executed it.

Everything below runs and is genuinely evaluated against the iCE40UP5K
*silicon family* (`--up5k`, `-d up5k`) -- that is a fact about which chip,
not which board, and is exactly what the user specified. It never touches
pin placement.

## M9 finding #1: Yosys 0.33 cannot parse this project's SystemVerilog

Yosys 0.33's native `read_verilog -sv` frontend does not support
SystemVerilog package imports (`import rv32_pkg::*;`) at all, in either
module-header or module-body position -- confirmed with independent minimal
repros for both, each failing with a distinct parser error
(`unexpected TOK_ID` / `unexpected TOK_PACKAGESEP`). Since nearly every RTL
file in this project imports `rv32_pkg` exactly this way, this blocked
synthesis outright.

`sv2v` (the standard workaround: converts SystemVerilog to plain Verilog
before handing it to a Verilog-2005-era frontend like Yosys's) is not
available via `apt`, and building it from source needs a Haskell toolchain
(`ghc`/`cabal`/`stack`) not installed in this sandbox by default.

**Resolution:** `scripts/gen_synth_rtl.py` performs a narrow, fully
mechanical, line-level text transform -- deliberately *not* a general
SystemVerilog-to-Verilog converter:

1. `rtl/core/rv32_pkg.sv`'s `package rv32_pkg; ... endpackage` wrapper
   lines are deleted; the unchanged body is wrapped in an
   `` `ifndef``/`` `define``/`` `endif `` include guard (needed because
   Yosys shares preprocessor state across every file in one `read_verilog`
   invocation -- without the guard, a type/localparam pulled in by two
   files in the same run collides as a duplicate declaration) and written
   to `build/synth/rv32_pkg.svh`.
2. Every other RTL file is copied byte-for-byte into `build/synth/`,
   except that any line consisting *only* of `import rv32_pkg::*;` is
   deleted, and `` `include "rv32_pkg.svh" `` is prepended at the top.

That's the whole transform: two literal line deletions and one literal
line insertion, with no Verilog parsing anywhere in the script. It was
verified correct with minimal repros *before* being applied to the real
RTL (including the specific failure mode of two files each including the
same header colliding without the guard). **The `rtl/` sources every
testbench simulates under Icarus/Verilator are never modified** -- this
script only ever writes to `build/synth/`, and only Yosys reads that
directory. Every `synth*` Makefile target regenerates it fresh.

Two smaller, related parser gaps, fixed directly in the real RTL sources
(not just the synth copy) using the same idiom, since both are also
standard, permanent good practice independent of this specific tool:

- **Immediate assertions**: Yosys's frontend cannot parse
  `assert (...) else $error(...);` inside `always_ff` at all (confirmed
  independently of the `-noassert` flag, which requires the statement to
  already parse). `read_verilog` implicitly defines `` `SYNTHESIS `` unless
  `-nosynthesis` is passed, and neither Icarus nor Verilator define it by
  default -- so every assertion block (`rv32_core.sv`, `rv32_single.sv`) is
  now wrapped in `` `ifndef SYNTHESIS ... `endif ``. Simulation is
  unaffected; Yosys skips the block before ever reaching the parser.
- **`parameter string`**: Yosys's frontend cannot parse a `string`-typed
  parameter *declaration* at all (separate from, and unrelated to, the
  Icarus hierarchy-relay limitation already documented in
  `soc_top.sv`). `imem.sv`/`dmem.sv`'s `INIT_FILE` parameter (simulation-
  only; real programs are loaded via `defparam` on the leaf instance, never
  as a relayed parameter -- see `soc_top.sv`) is now conditionally excluded
  from the parameter list under `` `ifndef SYNTHESIS ``, along with the
  `initial`-block `$readmemh` that consumes it.

## M9 finding #2: real block RAM is synchronous-read; this project's memory boundary is not

This is the significant architectural finding of this milestone, not a
tooling quirk. `rtl/soc/imem.sv`/`dmem.sv` implement the zero-wait-state
baseline documented since Section 5: reads are purely **combinational**
(`assign rdata = {mem[...], ...}`). Every real iCE40 memory primitive --
both `SB_RAM40_4K` (EBR) and `SB_SPRAM256KA` (SPRAM) -- is a **synchronous-
read** hardware block; there is no such thing as a large, single-cycle,
purely-combinational-read memory primitive on real FPGA silicon.

Confirmed directly: synthesizing `soc_top` with the real 64 KiB memory map
(`docs/memory_map.md`) causes Yosys's `memory_collect`/`memory_bram` passes
to fall back to converting each memory array directly into individual
flip-flops (`created 65536 $dff cells ... read interface: ... 262140 $mux
cells`) for **each** of `imem`/`dmem`, because there is no adjacent read
register for the BRAM/SPRAM inference pass to latch onto (its own log
output says so explicitly: `Extracted addr FF from read port ...` finds
nothing to extract). This reproduces identically with `synth_ice40 -spram`
(which exists specifically to request `SB_SPRAM256KA` inference) -- the
flag doesn't help, because the mismatch is about read timing, not about
which primitive is being requested. The resulting register-based netlist
is not just large, it does not fit: iCE40UP5K has 5,280 logic cells total,
and two independent 64 KiB register-based memories alone would need
~131,072 flip-flops before any pipeline/glue logic is even counted.

**This is a genuine, load-bearing limitation, not a synthesis-flow
workaround.** Fixing it for real means giving `imem`/`dmem` a registered
read port and extending the CPU boundary contract to use the
already-present-but-currently-dormant `imem_ready`/`dmem_ready` signals for
a real wait-state stall (the hazard unit would gain a new "memory not
ready" stall condition alongside the existing load-use stall). That is a
pipeline-level architectural change with its own hazard-correctness
surface, deserving its own milestone with full regression re-verification
-- not something to retrofit in the last steps of a "best-effort" synthesis
milestone. It is recorded here as concrete, actionable future work (see
the README's "Known Limitations" and "Future Extensions").

## What was actually synthesized, placed, and routed

Given the above, M9's real results split into two honest, separately
meaningful pieces:

### 1. `rv32_core` alone -- the real, complete result

`rv32_core` (the CPU itself) has **no internal memory arrays** -- `imem`/
`dmem` are external ports, not instantiated inside it -- so this finding
does not apply to it at all. `make synth` synthesizes it with no caveats,
no downsizing, and no workarounds beyond the mechanical package-import fix
above:

```
=== rv32_core ===
  Number of cells:               4746
    SB_CARRY                      187
    SB_DFFE                        32
    SB_DFFESR                    1119
    SB_DFFSR                      549
    SB_LUT4                      2859
Executing CHECK pass: Found and reported 0 problems.
```

This is the meaningful utilization number for "the processor" -- a
complete, real RV32I 5-stage pipeline mapped entirely to real iCE40 cells.

### 2. `soc_top` -- a downsized but genuine full-SoC proof-of-flow

To still exercise the *full* synth -> place-and-route -> timing -> bitstream
flow on the actual top-level design (CPU + address decoder + GPIO + UART TX
+ reset sync), `make synth-soc-smoketest` (and the `pnr`/`timing`/
`bitstream` targets that depend on it) synthesizes `soc_top` with
`IMEM_ADDR_WIDTH`/`DMEM_ADDR_WIDTH` overridden via Yosys's `chparam` --
**not an RTL edit** -- down to 128 B / 32 B, comfortably holding the real
`uart_hello.S` program (65 B of `.text`, 11 B of `.data`) used to
initialize them (via the same `` `ifdef SYNTHESIS ``-guarded literal-path
`$readmemh` described below), while keeping the register-based memory
small enough to actually fit and route on the target device. This is a
genuine result for the downsized configuration, clearly not a claim about
the real 64 KiB map:

```
=== soc_top (IMEM=128B, DMEM=32B) ===
  Number of cells:               3810
    SB_CARRY                      193 | SB_DFFE   257 | SB_DFFESR  628
    SB_DFFR                         2 | SB_DFFSR  329 | SB_DFFSS     1
    SB_LUT4                      2400
Executing CHECK pass: Found and reported 0 problems.

nextpnr-ice40 (unconstrained -- no .pcf, see above):
  ICESTORM_LC:  3464/ 5280  65%
  SB_IO:          11/   96  11%
  Max frequency for clock 'clk': 16.04 MHz (PASS at 12.00 MHz)

icetime -d up5k -t:
  Timing estimate: 62.53 ns (15.99 MHz)
```

nextpnr's own post-route timing estimate and IceStorm's independent
`icetime` static analysis agree to within rounding (16.04 MHz vs.
15.99 MHz), which is good independent corroboration of the number. The
critical path (`synth/reports/soc_top_smoketest_timing.rpt`) runs through
the EX-stage forwarding mux into the hazard unit's comparison logic -- 40
logic levels, dominated by a long carry chain. No timing-driven flags
(`-abc9`, retiming, path restructuring) were used; this is an unoptimized
baseline, and that specific path is a reasonable first target if higher
Fmax is ever pursued.

A real, representative program's content is loaded into both memories for
this test specifically so the utilization/timing numbers reflect genuine
decoded logic, not an artifact of Yosys constant-folding an
uninitialized-ROM's fixed, unchanging fetch stream down to almost nothing
(an all-zero/all-X ROM was tried first and did produce a suspiciously tiny
netlist for exactly this reason before the real-content loading was added
-- see `imem.sv`/`dmem.sv`'s `` `ifdef SYNTHESIS `` branches). This is not
a functional requirement of the CPU/SoC -- override with
`make synth-soc-smoketest SMOKETEST_PROGRAM=sw/asm/other.S` (and the
`SMOKETEST_IMEM_BITS`/`SMOKETEST_DMEM_BITS` variables if the program needs
more room) to substitute a different one.

### The resulting bitstream is real but must never be programmed

`make bitstream` runs `icepack` on the routed smoke-test design, proving
the full open-source iCE40 flow (Yosys -> nextpnr -> IceStorm) completes
end-to-end. The `.bin` it produces is **unconstrained**: nextpnr placed
every I/O pad with zero pin constraints, so those pin assignments carry no
relationship to any real board's wiring and could just as easily land on a
pin the board depends on for something else (e.g. SPI flash). Combined with
the downsized-memory caveat above, this bitstream exists purely as a
proof-of-flow artifact. **Do not program it onto real hardware.**

## Makefile targets

| Target | What it does |
|---|---|
| `make synth` | Yosys `synth_ice40` on `rv32_core` alone. Clean, no caveats. |
| `make synth-soc-smoketest` | Yosys `synth_ice40` on `soc_top` with memory downsized via `chparam` (override with `SMOKETEST_*` variables). |
| `make pnr` | `nextpnr-ice40 --up5k` on the smoketest netlist, unconstrained (no `.pcf`/`--package`). |
| `make timing` | `icetime -d up5k -t` static timing analysis on the routed smoketest design. |
| `make bitstream` | `icepack` the routed smoketest design. Proof-of-flow only -- see above. |
| `make fpga-program` | Refuses to run and explains why (no confirmed board, no `.pcf`, no hardware access from this sandbox). |

All reports land in `synth/reports/`; see `docs/results/` for a curated
summary.

## FPGA memory initialization: a separate, still-open question

Confirming that a `$readmemh`-loaded literal path parses and attaches as a
`$mem_v2` `INIT` parameter in Yosys's RTLIL (as this milestone did) is not
the same as confirming that content survives all the way through
`nextpnr`/IceStorm into a programmed bitstream's actual power-up state.
iCE40UP5K's SPRAM primitives are commonly documented as having **no**
initialization capability in hardware at all (unlike the smaller EBR/BRAM-
style blocks), which would mean instruction/data memory content can only
ever be loaded post-configuration (e.g. over a debug/programming
interface), never baked into the bitstream, if a real (registered-read,
SPRAM-mapped) memory redesign is pursued later. This is unconfirmed and
listed as future work rather than assumed either way.
