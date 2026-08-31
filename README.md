# RV32I RISC-V Processor

A from-scratch RV32I RISC-V processor in SystemVerilog: unit RTL blocks, a
single-cycle reference core, a 5-stage pipeline with forwarding/stalling/
flushing, a board-independent SoC (memory-mapped GPIO and UART), a real GNU
toolchain build flow (no hand-written assembler), and best-effort synthesis
through place-and-route on an iCE40UP5K. Built as a real RTL engineering
project: every milestone is proven with automated, self-checking tests
before being called done, and every bug found along the way is root-caused
and documented rather than papered over. See `docs/` for the full design
record; this file is the map and the quick-start.

## Status

All of M0-M9 are implemented and verified; M10 (physical bring-up) is
documented as a procedure only -- see "Known Limitations" and
`docs/bringup.md`.

- **709/709 checks passing** across 22 testbenches (32 executions --
  10 directed programs each run against both the single-cycle and
  pipelined cores). `make lint` clean. See `docs/verification.md`.
- **Synthesizes to real iCE40 cells**: the CPU (`rv32_core`) synthesizes
  cleanly and completely (4,746 cells, 0 problems); the full SoC
  synthesizes, places, and routes on an iCE40UP5K at ~16 MHz for a
  memory configuration downsized to fit the current memory boundary's
  register-based fallback mapping. See `docs/fpga.md` and
  `docs/results/summary.md` for the full, honestly-caveated numbers.
- **No FPGA board confirmed yet** -- no pin constraints exist anywhere in
  this repository, on purpose. See "Supported Board" below.

## Quick start

```sh
make tools                              # verify the toolchain is present
make test                               # full regression: unit + core + SoC
make lint                               # Verilator --lint-only -Wall

make program PROGRAM=sw/asm/loop.S      # build one program with the real GNU toolchain
make dump    PROGRAM=sw/asm/loop.S      # objdump disassembly of the above
make wave    PROGRAM=sw/asm/loop.S      # VCD of rv32_core running it

make synth                              # Yosys synth_ice40 on rv32_core (clean)
make pnr                                # + nextpnr-ice40 on the soc_top smoke test
make timing                             # + icetime static timing analysis
make bitstream                          # + icepack (proof-of-flow only -- see docs/fpga.md)
```

If developing on macOS/Homebrew instead of this project's Ubuntu/apt
sandbox, override the toolchain prefix:
`make RISCV_PREFIX=riscv64-elf- test`.

## Architecture

RV32I base ISA only (see `docs/architecture.md` for exactly what that
excludes and how illegal instructions are handled). Two cores share every
unit module and the same `control_t`/`trace_t` vocabulary
(`rtl/core/rv32_pkg.sv`):

- `rv32_single.sv` -- single-cycle reference model.
- `rv32_core.sv` -- 5-stage pipeline (IF/ID/EX/MEM/WB), with EX-stage
  operand forwarding (`forward_unit.sv`), a load-use stall
  (`hazard_unit.sv`), a dedicated distance-3 WB->ID bypass, and a 2-stage
  flush on resolved branches/jumps.

Full details, the pipeline diagram, and the specific hazard-handling
reasoning: **`docs/architecture.md`**.

## Memory system

Flat 32-bit address space: 64 KiB instruction ROM at `0x0000_0000`, 64 KiB
data RAM at `0x1000_0000`, and memory-mapped UART TX / GPIO / status
registers from `0x2000_0000`. Full memory map, register semantics, and the
real ROM/RAM routing bug found and fixed along the way (why `.rodata` lives
in RAM): **`docs/memory_map.md`**.

## Verification

Self-checking testbenches at three levels (unit / core / SoC), golden
vectors derived from real toolchain output rather than hand-computed
values, a shared `` `CORE_DUT `` harness so every directed program proves
both cores agree, and a "poison canary" pattern for proving illegal
instructions have zero architectural effect. `make test` exits nonzero on
any failure. Full numbers and methodology: **`docs/verification.md`**.

## Toolchain

Real GNU RISC-V toolchain throughout -- **no hand-written assembler**.
`RISCV_PREFIX` isolates the one real environmental difference between this
project's Ubuntu/apt sandbox (`riscv64-unknown-elf-`) and a Homebrew/macOS
machine (`riscv64-elf-`); override it on the command line or environment,
never in RTL or software source. Every program is built
`-march=rv32i -mabi=ilp32 -mno-relax -ffreestanding -nostdlib -nostartfiles
-fno-builtin -Wl,--no-relax`, and `scripts/build_program.sh` checks the
resulting `objdump` disassembly against an RV32I-only mnemonic allowlist so
a test program can never silently contain an instruction this CPU doesn't
implement. Build flow: source -> `gcc`/`as` -> `.elf` -> `objdump` (kept, for
debugging) -> `objcopy` -> raw binary -> `scripts/bin2hex.py` (a pure
binary-to-`$readmemh`-hex format converter -- explicitly not an assembler)
-> `$readmemh` in simulation.

## How to run everything

| Command | What it does |
|---|---|
| `make tools` | verify every required tool is installed |
| `make lint` | Verilator `--lint-only -Wall` on all three integration levels |
| `make unit` / `make sim` / `make test` | unit tests / core tests / everything |
| `make program PROGRAM=sw/asm/x.S` | build one program with the real toolchain |
| `make dump PROGRAM=sw/asm/x.S` | `objdump` disassembly of the above |
| `make wave PROGRAM=sw/asm/x.S [DUT=rv32_single\|rv32_core]` | VCD waveform |
| `make synth` | synthesize `rv32_core` (Yosys `synth_ice40`) |
| `make synth-soc-smoketest` | synthesize the full `soc_top` (downsized memory) |
| `make pnr` | + `nextpnr-ice40 --up5k`, unconstrained |
| `make timing` | + `icetime` static timing analysis |
| `make bitstream` | + `icepack` (proof-of-flow only) |
| `make fpga-program` | refuses to run -- no board confirmed, see below |
| `make clean` | remove all build/synthesis artifacts |

## Supported board

**None, yet.** The intended target is an iCEBreaker (Lattice iCE40UP5K),
but it has not been purchased and its exact model/revision has not been
confirmed. Per this project's standing constraint, no pin assignment,
oscillator frequency, or programmer configuration is ever guessed:

- All RTL is board-independent; `fpga/boards/` is reserved and currently
  empty.
- No `.pcf` file exists anywhere in this repository.
- `make fpga-program` deliberately refuses to run rather than attempt
  anything.
- Everything synthesis-related in this project targets the iCE40UP5K
  **silicon family** (`--up5k`), which is a fact about the chip the user
  specified, not about any board's wiring.

Once a board is confirmed, `docs/bringup.md` lays out the staged (H0-H6)
physical bring-up procedure -- confirming pin/oscillator facts from the
board's own documentation, a minimal one-LED bitstream, UART bring-up, the
full memory map, GPIO, and a hardware regression pass -- none of which has
been executed (this sandbox has no USB/hardware access).

## Measured results

- **Verification:** 709/709 checks passing, 22 testbenches (32 executions),
  0 failures. `make lint` clean.
- **Synthesis (`rv32_core`, the real result, no caveats):** 4,746 cells
  (187 `SB_CARRY`, 32 `SB_DFFE`, 1,119 `SB_DFFESR`, 549 `SB_DFFSR`, 2,859
  `SB_LUT4`), 0 `CHECK`-pass problems.
- **Synthesis + PnR + timing (full `soc_top`, memory downsized -- see
  `docs/fpga.md`):** 3,464/5,280 logic cells (65%), 11/96 I/O (11%), routes
  successfully, ~16 MHz (nextpnr: 16.04 MHz; independent `icetime`:
  15.99 MHz) on an unoptimized baseline.

Full numbers, methodology, and exactly what is and isn't proven by them:
**`docs/results/summary.md`** and **`docs/fpga.md`**.

## Known Limitations

- **The CPU's zero-wait-state, combinational-read memory boundary does not
  map to real FPGA block RAM.** Real iCE40 memory primitives (both EBR and
  SPRAM) are synchronous-read only; this project's `imem`/`dmem` read
  combinationally. Confirmed directly in Yosys's synthesis log (falls back
  to one flip-flop per byte rather than inferring a memory primitive) --
  see `docs/fpga.md`. Fixing this for real means registering the read port
  and extending the hazard unit with a genuine memory-wait stall using the
  already-present-but-dormant `imem_ready`/`dmem_ready` signals; this is a
  pipeline-level change deserving its own milestone and full regression
  re-verification, not a last-minute retrofit, so it is left as the
  top future-work item rather than attempted here.
- **`.rodata` lives in RAM, not ROM.** The CPU's data port has no hardware
  route to the instruction-ROM region (Harvard boundary); a true dual-ported
  ROM would let read-only data live in ROM as usual. See
  `docs/memory_map.md`.
- **No board confirmed; no physical bring-up executed.** See "Supported
  Board" above and `docs/bringup.md`.
- **FPGA memory initialization beyond simulation is unconfirmed.** A
  `$readmemh`-loaded literal path does attach as Yosys `$mem_v2` `INIT`
  content, but whether that survives into a real programmed bitstream
  (iCE40UP5K's SPRAM primitives are commonly documented as having no
  init capability in hardware at all) is unconfirmed either way -- see
  `docs/fpga.md`.
- **Synthesis timing is an unoptimized baseline.** No `-abc9`/retiming/
  timing-driven flags were used; the identified critical path (EX-stage
  forwarding mux into the hazard unit's comparison logic) is a reasonable
  first target if higher Fmax is pursued.
- **No M/A/F/D/C or other ISA extensions, no CSR/trap/interrupt support,
  no debug/JTAG.** RV32I only, by design -- see `docs/architecture.md`.

## Future Extensions

- The registered-memory redesign above, unblocking real BRAM/SPRAM
  inference and the full 64 KiB memory map on real hardware.
- A true dual-ported (or unified) memory system so `.rodata` can live in
  ROM.
- Physical bring-up on a confirmed board, per `docs/bringup.md`.
- Timing-driven synthesis optimization once real hardware is in the loop.
- Zicsr/machine-mode trap handling, an interrupt controller, and a debug
  module, if the project grows beyond a bare-metal single-program target.
- `M` (multiply/divide) as the most likely first ISA extension, given how
  much bare-metal C code benefits from it.

## Repository layout

```
rtl/{core,pipeline,soc}   synthesizable RTL
tb/{unit,core,soc,common,programs}   testbenches + shared harnesses
sw/{asm,baremetal,linker,startup}    software + real toolchain build inputs
fpga/{boards,constraints,build}      reserved for board-specific work (empty)
synth/                               synthesis/PnR outputs (gitignored; regenerate via `make`)
docs/{results/}                      design record + curated results
scripts/                             build/test/lint/synthesis-preprocessing automation
build/                               generated (gitignored; regenerate via `make`)
```

See `docs/architecture.md`, `docs/memory_map.md`, `docs/verification.md`,
`docs/fpga.md`, `docs/bringup.md`, and `docs/results/summary.md` for the
full detail behind every section above.
