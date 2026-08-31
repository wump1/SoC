/* LUI and AUIPC. */
.section .text
.globl _start
_start:
    lui   x1, 0xABCDE   /* x1 = 0xABCDE000 */
auipc_here:
    auipc x2, 0            /* x2 = address of this instruction (+0) */
    auipc x3, 1               /* x3 = address of this instruction + 0x1000 */
halt:
    jal x0, halt
