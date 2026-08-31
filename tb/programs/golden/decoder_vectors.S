/*
 * Golden-vector source for tb/unit/tb_decoder.sv.
 *
 * Assembled with the real toolchain so every opcode/funct3/funct7 pattern
 * tb_decoder.sv checks against is an authoritative RV32I encoding, not a
 * hand-typed hex guess. Regenerate with:
 *
 *   riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax \
 *     -ffreestanding -nostdlib -nostartfiles -Wl,--no-relax \
 *     -Ttext=0x0 -o decoder_vectors.elf tb/programs/golden/decoder_vectors.S
 *   riscv64-unknown-elf-objdump -d decoder_vectors.elf
 *
 * Instruction encoding does not depend on address (branch/jump immediates
 * do, but tb_decoder.sv only checks the branch/jump *control* bits here,
 * not the immediate value -- that is imm_gen's job and is covered
 * separately by tb_imm_gen.sv against imm_vectors.S), so these are safe to
 * reorder or combine with other test sources.
 */
.section .text
.globl _start
_start:
    /* R-type ALU (rd=ra=x1, rs1=sp=x2, rs2=gp=x3) */
    add  x1, x2, x3
    sub  x1, x2, x3
    and  x1, x2, x3
    or   x1, x2, x3
    xor  x1, x2, x3
    sll  x1, x2, x3
    srl  x1, x2, x3
    sra  x1, x2, x3
    slt  x1, x2, x3
    sltu x1, x2, x3

    /* I-type ALU (rd=ra=x1, rs1=sp=x2) */
    addi  x1, x2, 2047
    andi  x1, x2, -1
    ori   x1, x2, 255
    xori  x1, x2, -256
    slti  x1, x2, -5
    sltiu x1, x2, 5
    slli  x1, x2, 7
    srli  x1, x2, 7
    srai  x1, x2, 7

    /* Upper immediate / PC-relative */
    lui   x5, 0x1
    auipc x6, 0

    /* Branch / jump */
    beq  x1, x1, 1f
    nop
1:
    jal  x7, 2f
    nop
2:
    jalr x0, 0(x7)

    /* Loads (rd=ra=x1, rs1=sp=x2) */
    lw   x1, 0(x2)
    lb   x1, 0(x2)
    lbu  x1, 0(x2)
    lh   x1, 0(x2)
    lhu  x1, 0(x2)

    /* Stores (rs2=ra=x1, rs1=sp=x2) */
    sw   x1, 4(x2)
    sb   x1, 0(x2)
    sh   x1, 0(x2)

    /* SYSTEM / ordering: documented no-ops in this core */
    fence
    ecall
    ebreak
