/*
 * M2 minimal bring-up program (Appendix A.1 of the design spec).
 * Proves PC -> fetch -> decode -> regfile -> ALU -> writeback with just
 * ADDI/ADD/SUB, before anything else in the ISA is brought up.
 *
 * Expected final architectural state:
 *   x1 == 10
 *   x2 == 20
 *   x3 == 30
 *   x4 == 20
 */
.section .text
.globl _start
_start:
    addi x1, x0, 10
    addi x2, x0, 20
    add  x3, x1, x2      /* expect x3 = 30 */
    sub  x4, x3, x1      /* expect x4 = 20 */
halt:
    jal  x0, halt
