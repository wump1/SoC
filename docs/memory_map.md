# Memory Map

Single, flat 32-bit physical address space as seen by the CPU's data port.
Instruction fetch only ever addresses the ROM region (the CPU is a Harvard
design at its own boundary -- see `docs/architecture.md` -- but the SoC's
data-side address space below is what `address_decoder.sv` actually routes).

| Region              | Base         | Size  | End (inclusive) | Access     |
|----------------------|-------------|-------|------------------|------------|
| Instruction ROM      | `0x0000_0000` | 64 KiB | `0x0000_FFFF`  | fetch-only (data port has no route to it -- see below) |
| Data RAM             | `0x1000_0000` | 64 KiB | `0x1000_FFFF`  | read/write |
| UART TX data register | `0x2000_0000` | 4 B   | `0x2000_0003`  | write-only |
| GPIO output register | `0x2000_0004` | 4 B   | `0x2000_0007`  | read/write |
| Status/debug register | `0x2000_0008` | 4 B   | `0x2000_000B`  | read-only  |

Everything else is unmapped: a load returns `32'h0000_0000`, and a store is a
true no-op (`address_decoder.sv` gates every peripheral's own write-enable on
its own exact address match, so an unmapped store never lands on the wrong
peripheral by accident).

## Register details

**UART TX data register** (`0x2000_0000`, write-only): writing the low byte
of the stored word starts an 8N1 transmission (`rtl/soc/uart_tx.sv`). Poll
the status register's busy bit before writing again -- writing while busy is
not defined behavior for the transmitted byte and should be avoided by
software (the hardware does not queue or reject it).

**GPIO output register** (`0x2000_0004`, read/write): `wdata[GPIO_WIDTH-1:0]`
(default `GPIO_WIDTH = 8`) drives `gpio_out` combinationally-latched on the
next clock edge; the upper, unimplemented bits are discarded on write and
read back as those output bits' current value zero-extended -- there is no
separate storage for bits above `GPIO_WIDTH`.

**Status/debug register** (`0x2000_0008`, read-only): bit 0 = UART busy
(`1` while a transmission is in progress). All other bits are reserved and
read as zero.

## Why `.rodata` lives in RAM, not ROM

`rtl/core/rv32_core.sv` (and `rv32_single.sv`) is a Harvard-boundary CPU:
its instruction-fetch port (`imem_*`) and data port (`dmem_*`) are two
separate, independent ports, and only the data port is what
`address_decoder.sv` connects to RAM/UART/GPIO/status. There is no
hardware path from the data port to the instruction ROM -- so a load
targeting an address inside the ROM region would return `0x00000000`
(the address_decoder's "unmapped" default), not the ROM's actual content.

This was discovered as a real, initially-silent bug in M7/M8: the linker
script originally placed `.rodata` in the same output section as `.text`
(i.e. in ROM), and a `.rodata`-derived load correctly *linked* but silently
read back zero at runtime. `sw/linker/linker.ld` now places `.rodata` in the
same output section as `.data` (RAM) instead, and `scripts/build_program.sh`
extracts `.text`-only into the IMEM image and `.data`+`.rodata` together
into the DMEM image accordingly. See that file's header comment for the
extraction details.

**Known limitation:** this means read-only data physically lives in
writable RAM rather than ROM. A true dual-ported ROM (or giving the CPU's
data port a route to the ROM region) would let `.rodata` stay in ROM as
usual; that is out of scope for this project and is listed as future work
in the top-level README.

## Reset vector

`RESET_VECTOR = 32'h0000_0000` (`rtl/core/rv32_pkg.sv`) -- the PC always
starts at the base of instruction ROM.
