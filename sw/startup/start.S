/*
 * Bare-metal startup for C programs targeting this core. Placed in
 * .text.start, which sw/linker/linker.ld puts first in .text, so _start
 * always lands at the reset vector regardless of link order.
 *
 * Responsibilities: set the stack pointer, zero .bss (C assumes
 * zero-initialized statics without an explicit initializer -- nothing
 * else does this without an OS), call main, then spin forever on return
 * (there is nothing to return *to* on bare metal, and looping is a
 * deterministic, easy-to-detect-in-simulation halt rather than falling
 * through into whatever instruction follows).
 */
.section .text.start
.globl _start
_start:
    la   sp, _stack_top

    la   t0, _bss_start
    la   t1, _bss_end
clear_bss:
    bge  t0, t1, clear_bss_done
    sw   x0, 0(t0)
    addi t0, t0, 4
    j    clear_bss
clear_bss_done:

    jal  ra, main

halt:
    j    halt
