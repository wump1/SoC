/*
 * Full ALU coverage: every I-type and R-type ALU op, with negative
 * operands, signed vs. unsigned comparisons, and shifts up to 31 bits
 * with arithmetic sign propagation.
 */
.section .text
.globl _start
_start:
    addi x1, x0, -5      /* x1 = -5           = 0xFFFFFFFB */
    addi x2, x0, 3        /* x2 = 3 */
    lui  x3, 0x80000       /* x3 = 0x80000000 (INT_MIN) */
    addi x4, x0, -1         /* x4 = -1           = 0xFFFFFFFF */

    andi x5, x1, 0x0F        /* x5 = (-5) & 0xF        = 0xB (11) */
    ori  x6, x0, -1            /* x6 = 0 | sext(-1)      = 0xFFFFFFFF */
    xori x7, x4, -1              /* x7 = (-1) ^ sext(-1)   = 0 */

    slti  x8, x1, 0                /* x8 = (-5 < 0) signed    = 1 */
    sltiu x9, x1, 0                 /* x9 = (0xFFFFFFFB<0) unsigned = 0 */

    addi x10, x0, 1
    slli x11, x10, 31                /* x11 = 1<<31            = 0x80000000 */
    srli x12, x11, 31                 /* x12 = 0x80000000>>31 logical = 1 */
    srai x13, x11, 31                  /* x13 = 0x80000000>>>31 arith  = 0xFFFFFFFF */
    srai x14, x3, 4                     /* x14 = INT_MIN>>>4 arith      = 0xF8000000 */

    sub  x15, x0, x2                     /* x15 = 0-3              = -3 */
    and  x16, x1, x2                      /* x16 = (-5)&3           = 3 */
    or   x17, x1, x2                       /* x17 = (-5)|3           = -5 (0xFFFFFFFB) */
    xor  x18, x4, x2                        /* x18 = (-1)^3           = -4 (0xFFFFFFFC) */
    sll  x19, x10, x2                        /* x19 = 1<<3             = 8 */
    srl  x20, x11, x2                         /* x20 = 0x80000000>>3 logical = 0x10000000 */
    sra  x21, x11, x2                          /* x21 = 0x80000000>>>3 arith  = 0xF0000000 */
    slt  x22, x1, x2                            /* x22 = (-5<3) signed    = 1 */
    sltu x23, x1, x2                             /* x23 = (0xFFFFFFFB<3) unsigned = 0 */
    slt  x24, x2, x1                              /* x24 = (3<-5) signed    = 0 */
    sltu x25, x2, x1                               /* x25 = (3<0xFFFFFFFB) unsigned = 1 */
halt:
    jal x0, halt
