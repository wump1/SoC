/*
 * All six branch comparisons, each exercised both taken and not-taken.
 * x31 is a poison canary: every taken-branch case is immediately followed
 * by an instruction that must be skipped (it corrupts x31 if reached), and
 * every not-taken case is followed by an instruction that must execute
 * (it sets a distinct marker register). x31 == 0 at the end proves no
 * branch ever took the wrong path. Ends with a real backward-branch loop.
 */
.section .text
.globl _start
_start:
    addi x1, x0, 5
    addi x2, x0, 5
    addi x3, x0, 10
    addi x31, x0, 0        /* poison canary: must stay 0 */

    beq  x1, x2, 1f          /* taken (5==5) */
    addi x31, x31, 1
1:
    beq  x1, x3, 2f            /* not-taken (5!=10) */
    addi x4, x0, 111
2:
    bne  x1, x3, 3f              /* taken (5!=10) */
    addi x31, x31, 1
3:
    bne  x1, x2, 4f                /* not-taken (5==5) */
    addi x5, x0, 222
4:
    addi x6, x0, -1
    addi x7, x0, 1
    blt  x6, x7, 5f                  /* taken signed (-1<1) */
    addi x31, x31, 1
5:
    blt  x7, x6, 6f                    /* not-taken signed (1<-1 false) */
    addi x8, x0, 333
6:
    bge  x7, x6, 7f                      /* taken signed (1>=-1) */
    addi x31, x31, 1
7:
    bge  x6, x7, 8f                        /* not-taken signed (-1>=1 false) */
    addi x9, x0, 444
8:
    bltu x7, x6, 9f                          /* taken unsigned (1 < 0xFFFFFFFF) */
    addi x31, x31, 1
9:
    bltu x6, x7, 10f                           /* not-taken unsigned (huge<1 false) */
    addi x10, x0, 555
10:
    bgeu x6, x7, 11f                             /* taken unsigned (huge>=1) */
    addi x31, x31, 1
11:
    bgeu x7, x6, 12f                               /* not-taken unsigned (1>=huge false) */
    addi x11, x0, 666
12:
    addi x12, x0, 3           /* backward-branch loop: count 3 down to 0 */
loop:
    addi x12, x12, -1
    bne  x12, x0, loop
halt:
    jal x0, halt
