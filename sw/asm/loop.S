/*
 * A real backward-branch loop: sum 1..10 using ADD/ADDI/BLT, exercising
 * sustained multi-iteration execution rather than a single taken branch.
 * Expected: x1 (sum) == 55.
 */
.section .text
.globl _start
_start:
    addi x1, x0, 0     /* sum = 0 */
    addi x2, x0, 1       /* i = 1 */
    addi x3, x0, 11        /* limit = 11 (loop while i < 11, i.e. i = 1..10) */
loop:
    add  x1, x1, x2
    addi x2, x2, 1
    blt  x2, x3, loop
halt:
    jal x0, halt
