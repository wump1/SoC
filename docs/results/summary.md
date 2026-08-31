# Results Summary

Curated, permanent record of this project's verification and synthesis
results. Full raw tool logs are regenerable (`make test`, `make lint`,
`make synth`, `make synth-soc-smoketest`, `make pnr`, `make timing`,
`make bitstream`) and land in `synth/reports/`, which is gitignored on
purpose -- this file is the committed summary of what those runs produced,
not a substitute for re-running them. See `docs/verification.md` and
`docs/fpga.md` for the full narrative behind these numbers.

## Test summary

```
make test
...
TOTAL: 32 passed, 0 failed
```

| Level | Testbenches | Executions | Checks |
|---|---|---|---|
| Unit (`tb/unit/`) | 9 | 9 | 484 |
| Core (`tb/core/`), vs. `rv32_single` | 10 | 10 | 92 |
| Core (`tb/core/`), vs. `rv32_core` (pipeline) | 10 | 10 | 92 |
| SoC (`tb/soc/`) | 3 | 3 | 41 |
| **Total** | **22 distinct** | **32** | **709** |

0 failures. `make lint` (Verilator `--lint-only -Wall` on `rv32_single`,
`rv32_core`, and `soc_top`) is clean, with only individually-documented
benign warnings filtered -- see `scripts/run_lint.sh`'s header comment.

## Synthesis: `rv32_core` (the CPU, no memory arrays -- the real result)

```
$ make synth
=== rv32_core ===
   Number of wires:               1534
   Number of wire bits:           9860
   Number of cells:               4746
     SB_CARRY                      187
     SB_DFFE                        32
     SB_DFFESR                    1119
     SB_DFFSR                      549
     SB_LUT4                      2859
Executing CHECK pass (checking for obvious problems).
Checking module rv32_core...
Found and reported 0 problems.
```

No caveats: `rv32_core` has no internal memory arrays (`imem`/`dmem` are
external ports), so it maps completely to real iCE40UP5K cells via
`synth_ice40` with no downsizing and no workarounds beyond the mechanical
package-import preprocessing documented in `docs/fpga.md`.

## Synthesis + PnR + timing: `soc_top` smoke test (downsized memory)

`docs/fpga.md` documents why the *real* 64 KiB memory map does not
currently map to real block RAM/SPRAM at all (the zero-wait-state,
combinational-read memory boundary is fundamentally incompatible with
iCE40's synchronous-read-only memory primitives -- confirmed, not assumed).
The numbers below are for the full top-level SoC (CPU + address decoder +
GPIO + UART TX + reset sync) with `IMEM_ADDR_WIDTH=7` (128 B) /
`DMEM_ADDR_WIDTH=5` (32 B), loaded with the real `uart_hello.S` program, so
this is a genuine result for that configuration -- not a claim about the
real memory map.

```
$ make synth-soc-smoketest
=== soc_top ===
   Number of cells:               3810
     SB_CARRY                      193
     SB_DFFE                       257
     SB_DFFESR                     628
     SB_DFFR                         2
     SB_DFFSR                      329
     SB_DFFSS                        1
     SB_LUT4                      2400
Found and reported 0 problems.

$ make pnr        # nextpnr-ice40 --up5k, unconstrained (no .pcf/--package)
Info: Device utilisation:
Info: 	         ICESTORM_LC:  3464/ 5280    65%
Info: 	        ICESTORM_RAM:     0/   30     0%
Info: 	               SB_IO:    11/   96    11%
Info: 	               SB_GB:     8/    8   100%
Info: Max frequency for clock 'clk$SB_IO_IN_$glb_clk': 16.04 MHz (PASS at 12.00 MHz)

$ make timing     # icetime -d up5k -t (independent static timing analysis)
// Timing estimate: 62.53 ns (15.99 MHz)
```

nextpnr's own post-route timing estimate (16.04 MHz) and IceStorm's
independent `icetime` analysis (15.99 MHz) agree to within rounding --
good corroboration of the number from two independent tools. Neither run
used timing-driven optimization flags (`-abc9`, retiming); this is an
unoptimized baseline. The critical path runs through the EX-stage
forwarding mux into the hazard unit's comparison logic (40 logic levels,
dominated by a long carry chain) -- see `synth/reports/soc_top_smoketest_timing.rpt`
(regenerate with `make timing`) for the full path.

```
$ make bitstream  # icepack -- proof-of-flow only, see docs/fpga.md
wrote synth/soc_top_smoketest.bin -- UNCONSTRAINED, proof-of-flow only,
DO NOT program onto real hardware (see docs/fpga.md)
```

## What these numbers do and don't prove

**Proven:** this project's RTL, once mechanically preprocessed around three
specific, documented Yosys 0.33 SystemVerilog frontend gaps (package
imports, immediate assertions, `parameter string`), synthesizes cleanly to
real iCE40 technology cells with zero `CHECK`-pass problems; the CPU alone
(`rv32_core`) does so at full, real size with no caveats; the full SoC
integration synthesizes, places, and routes successfully on an iCE40UP5K
at a genuine ~16 MHz, for a memory configuration deliberately downsized to
fit within the register-based fallback mapping that this project's current
memory boundary requires.

**Not proven (and explicitly not claimed):** that the real 64 KiB memory
map fits or synthesizes to real block RAM (`docs/fpga.md` shows concretely
why it currently doesn't); that any bitstream produced here has been
programmed onto, or would behave correctly on, real hardware (no board is
confirmed and no `.pcf` exists -- see `docs/bringup.md`); or any Fmax
number beyond this specific unoptimized, downsized configuration.
