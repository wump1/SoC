/*
 * Transmits "RV32I OK\r\n" over the UART, polling the status register's
 * busy bit before each byte so back-to-back stores never drop one.
 */
.section .text
.globl _start
_start:
    lui  x1, 0x20000        /* x1 = UART TX data register (0x20000000) */
    lui  x2, 0x20000
    addi x2, x2, 8             /* x2 = status register (0x20000008), bit0 = uart busy */

    la   x3, message
    la   x4, message_end

send_loop:
    beq  x3, x4, halt
    lbu  x5, 0(x3)
wait_busy:
    lw   x6, 0(x2)
    andi x6, x6, 1
    bne  x6, x0, wait_busy
    sw   x5, 0(x1)
    addi x3, x3, 1
    j    send_loop
halt:
    j    halt

.section .rodata
message:
    .ascii "RV32I OK\r\n"
message_end:
