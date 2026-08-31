/*
 * Confirms an unsupported/illegal encoding can never commit a register or
 * memory write, and that the CPU simply advances past it as an inert
 * no-op rather than corrupting state or hanging.
 *
 * The injected .word is 0xFFFFFFFF: opcode[6:0]=1111111 matches none of
 * this core's defined RV32I opcodes, so the decoder marks it illegal; its
 * rd field (bits [11:7]) happens to decode to x31, the poison canary --
 * deliberately, to make the test maximally sensitive to a decoder bug
 * that lets reg_write slip through for an illegal instruction.
 *
 * This program is built with ALLOW_ILLEGAL=1 (see scripts/build_program.sh)
 * since it intentionally fails the normal "every mnemonic is real RV32I"
 * safety check that every other program in this suite must pass.
 */
.section .text
.globl _start
_start:
    addi x31, x0, 0    /* poison canary: must stay 0 */
    addi x1, x0, 10
    .word 0xFFFFFFFF     /* illegal encoding, rd field aliases x31 */
    addi x2, x0, 20
halt:
    jal x0, halt
