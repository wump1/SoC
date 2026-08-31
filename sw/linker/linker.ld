/*
 * Linker script for software targeting this RV32I core.
 *
 * Matches the project's logical memory map (docs/memory_map.md):
 *   0x00000000-0x0000FFFF  instruction ROM region  (.text)
 *   0x10000000-0x1000FFFF  data RAM region          (.rodata, .data, .bss, stack)
 * MMIO (UART/GPIO/status at 0x20000000+, added at M8) is deliberately not a
 * linker region: nothing is ever placed there by the linker, it is only
 * ever reached through explicit runtime store/load instructions.
 *
 * .rodata lives in RAM, not ROM, even though it never changes at
 * runtime: rtl/soc/address_decoder.sv only gives the CPU's *data* port
 * (LW/LB/...) a path to RAM and MMIO, not to imem's ROM array -- there is
 * no hardware route from a data-side load to the ROM region at all. A
 * string literal or const table linked into ROM would silently read back
 * as zero on real loads (caught by tb_uart_hello.sv: a message string
 * placed in ROM transmitted as all-zero bytes over UART). Building a true
 * dual-port ROM readable from both imem and dmem is future work; putting
 * .rodata in RAM is the conventional simple-SoC fix and is what every
 * program in this suite relies on, so keep it here rather than adjusting
 * per-program.
 *
 * Used for both directed assembly tests and bare-metal C. A pure assembly
 * test with no .data/.rodata of its own still links fine -- .data/.bss
 * are simply empty and _bss_start == _bss_end.
 */
ENTRY(_start)

MEMORY
{
  ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.text.start) /* startup code, if any, must run first */
    *(.text)
    *(.text.*)
  } > ROM

  .data : {
    _data_start = .;
    *(.rodata)
    *(.rodata.*)
    *(.data)
    *(.data.*)
    _data_end = .;
  } > RAM

  .bss : {
    _bss_start = .;
    *(.bss)
    *(.bss.*)
    *(COMMON)
    _bss_end = .;
  } > RAM

  . = ORIGIN(RAM) + LENGTH(RAM);
  _stack_top = .;

  /DISCARD/ : { *(.comment) *(.riscv.attributes) }
}
