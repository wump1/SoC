# Verification

## Philosophy

A milestone is not complete because the design compiles. Every milestone in
this project is proven with automated, self-checking tests, and `make test`
returns a nonzero exit status if any regression fails -- there is no manual
"eyeball the waveform" step in the pass/fail contract. When a test failed
during development, the response was always to find the actual root cause
(in the RTL, the testbench, or the toolchain) and fix it, never to weaken
the assertion or change the expected value to match whatever the RTL
happened to produce. Every bug found and fixed this way is documented in
its file's header comment or the relevant commit, not silently corrected.

## Self-checking pattern

`tb/common/tb_util.svh` is a shared include (not a package, since Icarus
needs it visible to every testbench file directly) providing two tasks:

- `tb_check(condition, message)` -- records a pass or a `$error`-logged
  failure with the message.
- `tb_summary(name)` -- prints the machine-parseable line every test's
  automation depends on:

  ```
  TESTBENCH_RESULT: PASS (12/12 checks) [tb_name]
  ```
  or `FAIL (n/m checks)` if anything failed. `scripts/run_tests.sh` greps
  for this line and fails the whole run (nonzero exit) if any testbench
  reports `FAIL` or never prints the line at all (e.g. it hung or crashed).

## Three test levels

**Unit tests** (`tb/unit/`, `make unit`) -- one testbench per module in
`rtl/core/`, each driving that module directly and in isolation (no CPU
integration). 9 testbenches, 484 checks. `tb_decoder.sv` alone contributes
357 of those: it exhaustively checks `control_t` field values across a wide
sweep of encodings, including the illegal-instruction gating behavior
described in `docs/architecture.md`.

**Core tests** (`tb/core/`, `make sim`) -- directed assembly programs built
with the real GNU toolchain (never a hand-written assembler -- see
`docs/toolchain` notes in the README) and run to completion against
`trace_t`. `tb/core/core_harness.svh`'s `` `CORE_DUT `` macro drives the
*same* testbench source against both `rv32_single` and `rv32_core`, so
every one of the 10 directed programs below is actually two test
executions -- 20 total -- proving the pipeline reproduces the single-cycle
reference model's architectural behavior instruction-for-instruction, not
just "looks right" on its own.

| Program | Checks | What it covers |
|---|---|---|
| `alu_ops.S` | 22 | every ALU/OP-IMM operation |
| `arith_basic.S` | 6 | basic arithmetic sanity |
| `branch.S` | 10 | all six branch conditions, taken and not-taken |
| `hazard_stress.S` | 11 | back-to-back data hazards across forwarding and load-use stall paths |
| `illegal_safety.S` | 5 | an illegal encoding never writes architectural state (poison-canary pattern, see below) |
| `jump.S` | 11 | `JAL`/`JALR`, including link-register and misaligned-target edge cases |
| `loadstore.S` | 14 | all load/store widths and signedness, including misalignment |
| `loop.S` | 4 | a real branch-driven loop |
| `sum_test.c` | 4 | a bare-metal C program (real `gcc` codegen, not hand-assembled) |
| `upper_imm.S` | 5 | `LUI`/`AUIPC` |

`illegal_safety.S`'s **poison canary** pattern: registers are pre-loaded
with a distinctive sentinel value, an illegal encoding executes, and the
test asserts every register still holds its sentinel -- proving the illegal
instruction had zero architectural effect, not merely that execution
"continued".

**SoC tests** (`tb/soc/`, part of `make test`) -- 3 testbenches, 41 checks,
against the full `soc_top` integration (CPU + memory + peripherals):
`tb_soc_smoke.sv` (basic integration sanity), `tb_gpio_blink.sv` (a real
compiled C program driving the GPIO register), and `tb_uart_hello.sv`
(decodes the actual `uart_tx` serial waveform bit-by-bit -- edge-detection
based, not level-`wait`-based, since a level-sensitive `wait` can resolve
mid-bit on back-to-back zero-gap bytes -- and compares the received bytes
against the literal expected ASCII string).

## Current status

22 distinct testbenches (32 executions, since 10 core tests each run
against both DUTs), **709 checks, 0 failures**. `make lint`
(`scripts/run_lint.sh`, Verilator `--lint-only -Wall` across `rv32_single`,
`rv32_core`, and `soc_top`) is clean, with only a fixed set of individually
documented, benign warnings filtered (see that script's header comment for
exactly which and why -- e.g. `imem_ready`/`dmem_ready` intentionally
unused by the zero-wait-state baseline). Re-run both with `make test` and
`make lint`.

## Golden vectors, not hand-computed expectations

Where a test needs a specific instruction encoding or expected numeric
result, it is derived from the real toolchain's own output (`objdump`
disassembly, or the compiler's actual codegen for a C source) rather than
hand-computed bit patterns -- so a test failure means the RTL disagrees
with what the toolchain actually produced, not with a possibly-wrong manual
calculation.

## Tooling notes (Icarus Verilog 12.0)

A handful of real Icarus limitations shaped how the testbenches and RTL are
written, each documented at its point of use: no `inside` operator; a
`-Wall` ternary between two enum literals needs an explicit cast (rewritten
as if/else throughout instead); `parameter string` cannot be relayed
through more than one level of module hierarchy (worked around with
`defparam` directly on leaf instances -- see `rtl/soc/soc_top.sv`'s header
comment); and a classic testbench race exists if a driving `always_ff`'s
enable signal is cleared at the *same* simulation time as the edge the DUT
samples on (undefined relative scheduling order) -- avoided by clearing
strictly after the edge (`@(posedge clk); #1; sig = 0;`).

Verilator's stricter `--lint-only -Wall` catches classes of bugs Icarus
does not (e.g. an enum-typed signal implicitly declared as plain `logic`
loses its type checking) and is run as a second, independent tool for
exactly that reason -- see `make lint`.
