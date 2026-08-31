/*
 * Load/store coverage: word roundtrip, per-byte write strobes and their
 * effect on the containing word, sign vs. zero extension for byte and
 * halfword loads, and halfword lane placement within a word.
 */
.section .text
.globl _start
_start:
    lui  x2, 0x10000      /* x2 = 0x10000000 (RAM base) */

    /* Word store/load roundtrip, negative value */
    addi x3, x0, -1000
    sw   x3, 0(x2)
    lw   x4, 0(x2)         /* expect x4 == x3 == -1000 */

    /* Four independent byte stores into one word; confirms write strobes
       land in the right lane and don't disturb the others. */
    addi x5, x0, 0x7A       /* positive byte (MSB=0) */
    addi x6, x0, -1          /* low byte 0xFF (MSB=1) */
    sb   x5, 4(x2)
    sb   x6, 5(x2)
    sb   x0, 6(x2)
    addi x7, x0, 0x55
    sb   x7, 7(x2)
    lw   x8, 4(x2)             /* expect 0x5500FF7A (little-endian) */

    lb   x9,  4(x2)              /* sign-extend(0x7A)  = 0x0000007A */
    lb   x10, 5(x2)                /* sign-extend(0xFF)  = 0xFFFFFFFF */
    lbu  x11, 5(x2)                  /* zero-extend(0xFF)  = 0x000000FF */

    /* Halfword store/load, sign vs zero extension */
    addi x12, x0, -2                  /* low halfword 0xFFFE */
    sh   x12, 8(x2)
    lh   x13, 8(x2)                     /* sign-extend(0xFFFE) = 0xFFFFFFFE */
    lhu  x14, 8(x2)                       /* zero-extend(0xFFFE) = 0x0000FFFE */

    /* Halfword lane placement: write the upper half of the same word. */
    li   x15, 0x1234
    sh   x15, 10(x2)
    lw   x16, 8(x2)                         /* expect 0x1234FFFE */
halt:
    jal x0, halt
