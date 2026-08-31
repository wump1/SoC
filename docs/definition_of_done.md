# Definition of Done

Final review against this project's standing requirements. Checked items
are verified (re-run the referenced command to confirm); unchecked items
are honestly still open, with the reason and where that's tracked.

## Toolchain & environment

- [x] Real GNU RISC-V toolchain used throughout; no hand-written assembler
      anywhere in the build flow. `scripts/bin2hex.py` is a pure binary ->
      `$readmemh`-hex format converter, not an assembler.
- [x] `RISCV_PREFIX` configurable (`Makefile`), defaulting to
      `riscv64-unknown-elf-` for this sandbox and overridable to
      `riscv64-elf-` for Homebrew/macOS, with that difference isolated to
      build configuration only -- never RTL or software source.
- [x] Every program built `-march=rv32i -mabi=ilp32 -mno-relax
      -ffreestanding -nostdlib -nostartfiles -fno-builtin -Wl,--no-relax`.
- [x] `scripts/build_program.sh` checks `objdump` output against an
      RV32I-only mnemonic allowlist so no test program can silently exceed
      the CPU's supported ISA.
- [x] `make tools` verifies every required tool and reports versions.

## RTL discipline

- [x] `always_ff`/`always_comb` throughout; no latches, no multiple
      drivers, no combinational loops (the one close call -- a same-cycle
      regfile bypass -- was caught, root-caused, and redesigned; see
      `rtl/core/regfile.sv`'s header comment).
- [x] `typedef enum`/`struct packed` and named opcodes/localparams
      (`rtl/core/rv32_pkg.sv`) instead of magic constants throughout.
- [x] `make lint` (Verilator `--lint-only -Wall`) clean across
      `rv32_single`, `rv32_core`, and `soc_top`, with only a fixed,
      individually-documented set of benign warnings filtered -- see
      `scripts/run_lint.sh`.

## Milestones

- [x] **M0** -- environment, tool verification, repo scaffolding.
- [x] **M1** -- unit RTL blocks, each with an independent self-checking
      testbench (`tb/unit/`, 9 testbenches, 484 checks).
- [x] **M2/M3** -- minimal, then complete, single-cycle RV32I core
      (`rv32_single.sv`), serving as the architectural reference model.
- [x] **M4** -- structural conversion to a 5-stage pipeline (`rv32_core.sv`).
- [x] **M5** -- forwarding, load-use stall, control-hazard flush, and the
      Section 9.3 safety assertions (bubbles/invalid entries can never
      write architectural state).
- [x] **M6** -- assembly regression suite wired into `make unit/sim/test`,
      built with the real GNU toolchain.
- [x] **M7** -- bare-metal C toolchain support (`sw/startup/start.S`,
      real `gcc`-compiled test programs).
- [x] **M8** -- FPGA SoC integration: address decoder, GPIO, UART TX,
      reset synchronizer, board-independent `soc_top`.
- [x] **M9** -- synthesis through place-and-route, best-effort. `rv32_core`
      synthesizes cleanly and completely; `soc_top` synthesizes, places,
      and routes for a memory configuration downsized to fit the current
      memory boundary's limitations. See "Known limitation" below and
      `docs/fpga.md` for the full, honest accounting of what this did and
      didn't achieve.
- [~] **M10** -- physical bring-up. Documented as a staged, board-
      independent procedure (`docs/bringup.md`) only -- **not executed**.
      This sandbox has no USB/hardware access, and no board has been
      confirmed yet; both are explicit, standing project constraints, not
      oversights.

## Testing philosophy

- [x] No milestone declared complete merely because the design compiled --
      every one is proven with automated tests before being reported done.
- [x] Every test failure encountered during development was root-caused
      and fixed at the source (RTL, testbench, or toolchain invocation),
      never worked around by weakening an assertion or changing an
      expected value to match incorrect RTL behavior. Every such bug is
      documented at its fix site (see `docs/verification.md` and the
      relevant file header comments) rather than hidden.
- [x] `make test` exits nonzero if any regression fails.
- [x] Golden vectors derived from real toolchain output, not hand-computed
      bit patterns.

## Board independence

- [x] No FPGA pin assignment, oscillator frequency, or programmer
      configuration guessed or invented anywhere in this repository.
- [x] No `.pcf` file exists.
- [x] All CPU/SoC RTL is board-independent; `fpga/boards/` is reserved and
      empty.
- [x] `make fpga-program` refuses to run rather than attempt anything,
      and explains why.
- [x] Physical bring-up documented (`docs/bringup.md`) as a procedure for
      the user to execute on real hardware, explicitly not claimed to have
      been run here.

## Documentation

- [x] `docs/architecture.md`, `docs/memory_map.md`, `docs/verification.md`,
      `docs/fpga.md`, `docs/bringup.md`, `docs/results/summary.md`.
- [x] Top-level `README.md` covering architecture, supported ISA,
      pipeline, hazards, memory system, toolchain, how to run/build/test/
      synthesize, supported board, measured results, known limitations,
      and future extensions.
- [x] This checklist.

## Known limitation carried forward (not a gap in this milestone's scope)

- [~] The CPU's zero-wait-state, combinational-read memory boundary does
      not map to real FPGA block RAM/SPRAM (both are synchronous-read-only
      in hardware) -- confirmed directly in the Yosys synthesis log, not
      assumed. Fixing this requires a registered-memory-port redesign and
      a new hazard-unit stall condition, which is a pipeline-level change
      warranting its own milestone and full regression re-verification --
      correctly scoped as future work rather than retrofitted here under
      M9's "best-effort" synthesis mandate. Tracked in `docs/fpga.md` and
      the README's "Known Limitations".

Every `[x]` above can be independently re-verified by running the
referenced command; nothing here is asserted without a way to check it.
