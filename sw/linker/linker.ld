/*
 * Linker script for software targeting this RV32I core.
 *
 * Matches the project's logical memory map (docs/memory_map.md):
 *   0x00000000-0x0000FFFF  instruction ROM region  (.text, .rodata)
 *   0x10000000-0x1000FFFF  data RAM region          (.data, .bss, stack)
 * MMIO (UART/GPIO/status at 0x20000000+, added at M8) is deliberately not a
 * linker region: nothing is ever placed there by the linker, it is only
 * ever reached through explicit runtime store/load instructions.
 *
 * Used for both directed assembly tests and bare-metal C. A pure assembly
 * test with no .data of its own still links fine -- .data/.bss are simply
 * empty and _bss_start == _bss_end.
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

  .rodata : {
    *(.rodata)
    *(.rodata.*)
  } > ROM

  .data : {
    _data_start = .;
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
