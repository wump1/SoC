/*
 * Pipeline hazard stress test: load-use interlock, forwarding at
 * dependency distances 1/2/3, and control-hazard wrong-path safety with a
 * destructive store (not just a register write) after a taken branch.
 * None of the other directed programs in this suite happen to place a
 * dependent instruction immediately after a load, so this is the only
 * program that actually exercises the load-use stall.
 */
.section .text
.globl _start
_start:
    lui  x2, 0x10000       /* x2 = RAM base */
    addi x3, x0, 77
    sw   x3, 0(x2)
    lw   x5, 0(x2)           /* load ... */
    addi x6, x5, 1              /* ... used by the very next instruction: load-use hazard */
    add  x7, x5, x5               /* ... and the one after that */

    /* Classic tight forwarding chain (spec Section "FORWARDING"). */
    addi x8, x0, 1
    addi x8, x8, 1
    addi x8, x8, 1
    addi x8, x8, 1                  /* expect x8 == 4 */

    /* Distance-1 forwarding (EX/MEM -> EX), both ALU operands at once. */
    addi x9, x0, 10
    addi x10, x0, 20
    add  x11, x9, x10
    add  x12, x11, x11                /* x11 produced by the immediately preceding instruction */

    /* Distance-2 forwarding (MEM/WB -> EX): one independent instruction
       sits between producer and consumer. */
    addi x13, x0, 5
    addi x14, x0, 0
    add  x15, x13, x13

    /* Distance-3 (regfile-adjacent tier-0 bypass): two independent
       instructions between producer and consumer. */
    addi x16, x0, 7
    addi x17, x0, 0
    addi x18, x0, 0
    add  x19, x16, x16

    /* Control-hazard wrong-path safety with a destructive STORE, not just
       a register write, immediately after a taken branch. */
    addi x20, x0, 0xAA        /* poison value */
    addi x21, x0, 1
    beq  x21, x21, skip_store   /* always taken */
    sw   x20, 100(x2)             /* must never execute */
skip_store:
    lw   x22, 100(x2)               /* must read back 0, not the poison value */
halt:
    jal x0, halt
