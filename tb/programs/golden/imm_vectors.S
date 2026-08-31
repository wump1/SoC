/*
 * Golden-vector source for tb/unit/tb_imm_gen.sv.
 *
 * Assembled with the real toolchain to get authoritative instruction
 * encodings and branch/jump offsets, instead of hand-computing the I/S/B/U/J
 * bit scatter (Section 4.3) by hand on both the RTL and testbench sides,
 * where a matching mistake in both places would cancel out and hide a bug.
 *
 * Regenerate with:
 *   riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax \
 *     -ffreestanding -nostdlib -nostartfiles -Wl,--no-relax \
 *     -Ttext=0x0 -o imm_vectors.elf tb/programs/golden/imm_vectors.S
 *   riscv64-unknown-elf-objdump -d imm_vectors.elf
 *
 * Then read the encoding (left hex column) and address off each
 * disassembled line; the expected immediate for a branch/jump is simply
 * (target_address - instruction_address), computed from the two addresses
 * objdump prints -- not re-derived from the encoding.
 */
.section .text
.globl _start
_start:
    addi x1, x0, 2047      /* I-type max positive */
    addi x2, x0, -2048     /* I-type max negative */
    addi x3, x0, -1        /* I-type all-ones */
    sw   x1, 2047(x2)      /* S-type max positive */
    sw   x1, -2048(x2)     /* S-type max negative */
back_target:
    nop
    nop
    beq  x1, x2, fwd_target   /* B-type forward branch */
    nop
    nop
    nop
    bne  x1, x2, back_target  /* B-type backward branch */
fwd_target:
    lui  x4, 0xABCDE             /* U-type */
    jal  x5, jal_fwd_target      /* J-type forward jump */
    nop
    nop
    nop
jal_back_target:
    nop
    jal  x6, jal_back_target     /* J-type backward jump */
jal_fwd_target:
    jalr x0, 0(x5)
