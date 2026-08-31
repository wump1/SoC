# Architecture

## Scope: RV32I, exactly

This project implements the RV32I base integer ISA and nothing more: all
R/I/S/B/U/J-type arithmetic, logic, shift, branch, jump, load, and store
instructions, plus `FENCE`/`ECALL`/`EBREAK` as documented no-ops (decoded
and accepted, no side effect -- there is no memory-ordering hardware to
fence and no trap/debug unit to enter). Every opcode outside that set
(including compressed instructions, `M`/`A`/`F`/`D`/etc. extensions, and
CSR instructions) decodes as illegal: `decoder.sv` sets `ctrl.illegal`, and
the core suppresses every register/memory-write side effect for that
instruction (see "Illegal instructions" below) rather than executing
something undefined. The GNU toolchain is deliberately built and invoked
as `-march=rv32i -mabi=ilp32` throughout (`Makefile`, `scripts/build_program.sh`)
specifically so test programs can never accidentally contain an instruction
this CPU doesn't implement.

## Two cores, one ISA, one shared decode/execute vocabulary

`rtl/core/rv32_pkg.sv` is the single source of truth for opcodes, `alu_op_e`,
`imm_sel_e`, `wb_sel_e`, `fwd_sel_e`, the full per-instruction `control_t`
decode bundle, the pipeline registers' trimmed per-stage bundles, and the
`trace_t` retire-trace shape both cores expose identically for verification.
Every module in `rtl/core/` and `rtl/pipeline/` reaches these via
`import rv32_pkg::*;`.

Two integration-level cores share every unit module in `rtl/core/`
(`pc`, `regfile`, `alu`, `imm_gen`, `decoder`, `branch_unit`,
`load_store_unit`, plus the pipeline-only `hazard_unit`/`forward_unit`):

- **`rv32_single.sv`** -- single-cycle core (M2/M3). Every instruction
  fetches, decodes, executes, accesses memory, and writes back in one
  clock. Serves as the architectural reference model: any test written
  against its `trace_t` output is, by construction, a statement of
  correct architectural behavior, independent of pipelining concerns.
- **`rv32_core.sv`** -- 5-stage pipeline (M4/M5): IF, ID, EX, MEM, WB.

Both expose an identical boundary contract (Harvard-style, separate
instruction/data ports -- see "Memory boundary" below) and an identical
`trace_t` retire trace, so `tb/core/core_harness.svh`'s `` `CORE_DUT ``
macro lets the exact same testbench source drive either one
(`-DCORE_DUT=rv32_core` selects the pipeline; the default is
`rv32_single`). Every directed test program in `tb/core/` therefore proves
the same architectural behavior on both cores, which is what makes the
single-cycle core's correctness a meaningful reference for the pipeline's.

## Pipeline (`rv32_core.sv`)

```
IF ---> ID ---> EX ---> MEM ---> WB
   IF/ID    ID/EX   EX/MEM   MEM/WB
```

- **IF**: `pc.sv` drives the instruction address; `imem_addr`/`imem_rdata`
  are the fetch port.
- **ID**: `decoder.sv` produces the full `control_t`; `regfile.sv` reads
  `rs1`/`rs2`; `imm_gen.sv` extracts the immediate.
- **EX**: `alu.sv` computes; `branch_unit.sv` resolves branch/jump
  conditions and targets; `forward_unit.sv` selects each ALU operand
  between the register file's value and a still-in-flight result.
- **MEM**: `load_store_unit.sv` drives the data port and packs/unpacks
  byte/halfword/word loads and stores.
- **WB**: selects the value written back to `regfile.sv` (ALU result, memory
  load data, or PC+4 for `JAL`/`JALR`).

Pipeline registers (`rtl/pipeline/pipe_if_id.sv`, `pipe_id_ex.sv`,
`pipe_ex_mem.sv`, `pipe_mem_wb.sv`) each carry a `valid` bit alongside their
stage's control/data bundle. `IF/ID` and `ID/EX` accept `en` (stall: hold
current contents) and `flush` (insert a bubble and, for `IF/ID`, redirect
fetch) control inputs from the hazard unit and branch resolution
respectively. **`EX/MEM` and `MEM/WB` always advance, unconditionally** --
by the time a redirect or stall is detected, anything already latched in
those two registers belongs to an instruction that is either past the
point where a hazard could still change its outcome, or was already
invalidated earlier in its life (a flushed bubble's `valid=0` simply
propagates forward each cycle rather than needing to be re-flushed at every
stage).

## Hazards

**Data hazards -- forwarding (`forward_unit.sv`):** each EX-stage operand
is selected between the ID/EX-latched register value, the EX/MEM result
(one cycle ahead, not yet architecturally committed), or the MEM/WB result
(committing this cycle) -- EX/MEM wins when both could apply, since it is
the newer producer. `x0` is excluded on the producer side (`rd==0` never
forwards) and is naturally safe on the consumer side (`rs==0`'s ID/EX-latched
value is already zero). This covers dependency distances of 1 and 2 cycles.

**Data hazards -- load-use stall (`hazard_unit.sv`):** a load's data isn't
available until MEM, one cycle too late for EX-stage forwarding to help the
very next instruction if it reads the same register. When
`id_ex_mem_read && id_ex_rd == (if_id_rs1 or if_id_rs2)` (and `id_ex_rd !=
x0`), the hazard unit holds PC and IF/ID for one cycle and bubbles ID/EX,
so the dependent instruction re-enters EX exactly one cycle later, after
the load has reached MEM. Because hazard detection uses `if_id`'s raw
`rs1`/`rs2` bit-slices rather than a second decode, an instruction whose
those bit-fields happen to alias `id_ex_rd` without architecturally reading
a register (e.g. `LUI`, which doesn't read `rs1`/`rs2` at all) can trigger
an unnecessary stall. That costs a cycle, never correctness -- a real
dependency is never missed -- and is documented rather than "fixed" with a
second decoder solely for hazard detection.

**Data hazards -- distance-3 bypass:** a producer that retires in WB the
exact cycle a *different*, later instruction reads that register in ID is
one cycle further back than `forward_unit.sv` covers (by the time such a
producer would reach EX/MEM or MEM/WB, it has already left the pipeline).
`rv32_core.sv` resolves this itself, comparing ID's `rs1`/`rs2` against the
**pipeline register's** `mem_wb_rd` (never the currently-executing
instruction's own `rd` -- structurally, they can't alias) and bypassing
directly into the value `regfile.sv` would otherwise supply. This was
originally attempted as a same-cycle write-first bypass *inside*
`regfile.sv` itself; see that file's header comment for why that caused a
genuine combinational loop in the single-cycle core (any `rd==rs1`/`rs2`
instruction, e.g. `addi x1,x1,1`) and had to move out to this
structurally-safe comparison instead.

**Control hazards:** branches and jumps resolve in EX. A taken branch or
any jump flushes IF/ID and ID/EX (2-stage flush depth) and redirects fetch
to the resolved target the following cycle.

**Bubbles never have side effects:** every bubble carries `valid=0` through
the pipeline, and every register-file write and every memory write is
gated on its originating stage's `valid`. Section 9.3's safety assertions
in `rv32_core.sv` (simulation-only, `` `ifndef SYNTHESIS `` -- see
`docs/fpga.md`) directly check this: an invalid `MEM/WB` entry can never
assert `reg_write`, an invalid `EX/MEM` entry can never assert a memory
access, and the PC stays word-aligned every cycle.

## Illegal instructions

`decoder.sv` computes `illegal` first, per case arm (`LOAD`/`STORE`/`OP`/etc.),
and every other control field in that arm is gated on it inline
(if/else, not ternaries -- Icarus under `-Wall` requires an explicit cast
for an enum-typed ternary, so if/else is used throughout for readability
and portability). An illegal instruction decodes with every enable bit
(`reg_write`, `mem_read`, `mem_write`) forced to zero: it flows through the
pipeline like any other instruction (so it still occupies a cycle and can
still be forwarded-around by later instructions, exactly like a real,
harmless no-op) but can never write architectural state. `FENCE`/`ECALL`/
`EBREAK` decode as legal, side-effect-free no-ops rather than illegal,
matching their documented semantics for a core with no memory-ordering
hardware and no trap/debug unit.

## Memory boundary

Both cores are Harvard-style at their own module boundary: independent
`imem_req/addr/rdata/ready` and `dmem_req/we/addr/wdata/wstrb/rdata/ready`
ports, not a unified bus. `imem_ready`/`dmem_ready` are accepted but
currently unused by the CPU itself -- the project's zero-wait-state
baseline (every `rtl/soc/*mem.sv` ties `ready` high, and reads are purely
combinational) doesn't yet need them; they exist so a future wait-state-
capable memory (real block RAM has synchronous, not combinational, read --
see `docs/fpga.md`) can be substituted without changing the CPU's port
list, only its currently-dormant stall behavior.

`rtl/soc/soc_top.sv` is where the CPU boundary meets a concrete memory
system: `imem`/`dmem` (byte-addressable, `$readmemh`-initializable),
`address_decoder` (routes the data port to RAM or an MMIO peripheral --
see `docs/memory_map.md`), `gpio`, `uart_tx`, and `reset_sync` (2-flop
async-assert/sync-deassert reset synchronizer, since board-level reset
lines are asynchronous). `soc_top` itself stays completely board-agnostic:
no pin names, no programmer-specific anything -- see the top of that file
and `docs/fpga.md`'s board-independence discussion.

## Module inventory

| Module | Role |
|---|---|
| `rtl/core/rv32_pkg.sv` | shared opcodes/enums/structs, single source of truth |
| `rtl/core/pc.sv` | program counter, synchronous active-low reset |
| `rtl/core/regfile.sv` | 32x32-bit register file, `x0` hardwired to zero |
| `rtl/core/alu.sv` | arithmetic/logic/shift/compare |
| `rtl/core/imm_gen.sv` | I/S/B/U/J immediate extraction |
| `rtl/core/decoder.sv` | instruction -> `control_t` |
| `rtl/core/branch_unit.sv` | branch condition evaluation + target computation |
| `rtl/core/load_store_unit.sv` | byte/halfword/word load/store packing, misalignment detection |
| `rtl/core/hazard_unit.sv` | load-use stall detection |
| `rtl/core/forward_unit.sv` | EX-stage operand forwarding selection |
| `rtl/core/rv32_single.sv` | single-cycle integration (reference model) |
| `rtl/pipeline/pipe_if_id.sv`, `pipe_id_ex.sv`, `pipe_ex_mem.sv`, `pipe_mem_wb.sv` | pipeline registers |
| `rtl/pipeline/rv32_core.sv` | 5-stage pipeline integration |
| `rtl/soc/imem.sv`, `dmem.sv` | instruction ROM / data RAM |
| `rtl/soc/address_decoder.sv` | data-port address routing |
| `rtl/soc/gpio.sv`, `uart_tx.sv` | memory-mapped peripherals |
| `rtl/soc/reset_sync.sv` | async-assert/sync-deassert reset synchronizer |
| `rtl/soc/soc_top.sv` | board-independent SoC integration |
