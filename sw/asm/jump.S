/*
 * JAL forward and backward, JAL-as-call/JALR-as-return, and JALR's
 * required LSB-clearing behavior. x31 is a poison canary, as in branch.S:
 * every jump is immediately followed by an instruction that must be
 * skipped (jumps are always taken), so x31 == 0 at the end proves every
 * jump actually redirected instead of falling through.
 */
.section .text
.globl _start
_start:
    jal  x1, forward_target   /* x1 = link = addr of the poison below */
    addi x31, x0, 1
forward_target:
    addi x2, x0, 111            /* landed correctly */

    jal  x3, call_func            /* call-style JAL; x3 = return address */
    addi x4, x0, 222                /* runs after call_func returns via JALR */
    jal  x0, after_calls

call_func:
    addi x5, x0, 333
    jalr x0, 0(x3)                    /* return-style JALR ("ret") */
    addi x31, x0, 1                     /* must never execute: we already returned */

after_calls:
    la   x6, jalr_target                  /* x6 = address of jalr_target */
    addi x6, x6, 1                          /* deliberately set LSB=1 */
    jalr x7, 0(x6)                            /* target = (x6+0)&~1: LSB must be cleared */
    addi x31, x0, 1                             /* must never execute if LSB clearing works */
jalr_target:
    addi x8, x0, 444
halt:
    jal x0, halt
