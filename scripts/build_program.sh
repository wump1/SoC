#!/usr/bin/env bash
# Builds one program (assembly or C) for the RV32I core, producing
# everything simulation needs: an ELF, a disassembly, and per-region
# $readmemh hex images. Retains the ELF and disassembly for debugging
# (never just the final hex), per the project's build-flow contract:
#
#   program.S/.c -> gcc/as -> program.elf -> objdump -> program.dump
#                -> objcopy -> raw binary -> bin2hex.py -> *.hex -> $readmemh
#
# Usage: scripts/build_program.sh <source.S|source.c> <output_dir>
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <source.S|source.c> <output_dir>" >&2
  exit 1
fi

SRC="$1"
OUT_DIR="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RISCV_PREFIX="${RISCV_PREFIX:-riscv64-unknown-elf-}"
CC="${RISCV_PREFIX}gcc"
OBJDUMP="${RISCV_PREFIX}objdump"
OBJCOPY="${RISCV_PREFIX}objcopy"

if ! command -v "$CC" >/dev/null 2>&1; then
  echo "error: $CC not found (RISCV_PREFIX=$RISCV_PREFIX)" >&2
  exit 1
fi

NAME="$(basename "${SRC%.*}")"
LINKER="$REPO_ROOT/sw/linker/linker.ld"

# Every program for this core targets exactly RV32I/ilp32 (Section "ISA
# TARGET"): no M/A/F/D/C, no relaxation-driven surprises, no libc.
CFLAGS=(-march=rv32i -mabi=ilp32 -mno-relax -ffreestanding -nostdlib
        -nostartfiles -fno-builtin -Wl,--no-relax -T "$LINKER")

mkdir -p "$OUT_DIR"
ELF="$OUT_DIR/$NAME.elf"
DUMP="$OUT_DIR/$NAME.dump"
IMEM_BIN="$OUT_DIR/$NAME.imem.bin"
DMEM_BIN="$OUT_DIR/$NAME.dmem.bin"
IMEM_HEX="$OUT_DIR/$NAME.imem.hex"
DMEM_HEX="$OUT_DIR/$NAME.dmem.hex"

"$CC" "${CFLAGS[@]}" -o "$ELF" "$SRC"
"$OBJDUMP" -d "$ELF" > "$DUMP"

# Every mnemonic the objdump shows must be either a real RV32I instruction
# this core implements or a GNU-as pseudo-instruction that expands to one
# (li/mv/j/ret/...) -- fail loudly instead of silently simulating something
# the CPU can't execute. Checked as an explicit allowlist (not a denylist
# for M/A/F/D/C mnemonics): a denylist pattern broad enough to catch every
# extension's mnemonics is also broad enough to false-match the *encoding*
# column objdump prints right before the mnemonic (hex words starting with
# 'f' look like float mnemonics; "fence" itself, a real supported
# instruction, looks like one too) -- the allowlist has no such ambiguity,
# it only ever matches field 3 of an instruction line.
# ALLOW_ILLEGAL=1 skips this check for the one directed test
# (sw/asm/illegal_safety.S) that deliberately embeds a `.word` raw illegal
# encoding on purpose, to prove the decoder/CPU treat it as an inert no-op
# rather than committing a register or memory write. Every other program
# must pass this check.
if [ "${ALLOW_ILLEGAL:-0}" != "1" ]; then
  ALLOWLIST=" add sub sll slt sltu xor srl sra or and \
    addi slti sltiu xori ori andi slli srli srai \
    lui auipc jal jalr beq bne blt bge bltu bgeu \
    lb lh lw lbu lhu sb sh sw fence fence.i ecall ebreak \
    nop li mv not neg seqz snez sltz sgtz beqz bnez blez bgez bltz bgtz \
    j jr ret call tail la "
  bad_mnemonics="$(awk -F'\t' 'NF>=3 { print $3 }' "$DUMP" | sort -u | while read -r m; do
    case "$ALLOWLIST" in
      *" $m "*) ;;
      *) echo "$m" ;;
    esac
  done)"
  if [ -n "$bad_mnemonics" ]; then
    echo "error: $DUMP uses mnemonic(s) outside this core's RV32I subset:" >&2
    echo "$bad_mnemonics" | sed 's/^/  /' >&2
    exit 1
  fi
fi

"$OBJCOPY" -O binary --only-section=.text --only-section=.rodata "$ELF" "$IMEM_BIN"
"$OBJCOPY" -O binary --only-section=.data "$ELF" "$DMEM_BIN"

# Both hex files are addressed relative to their own region (0-based): the
# sram_model test memory (and the real rtl/soc/dmem.sv at M8) subtract each
# region's base address from an incoming access before indexing into it, so
# $readmemh's @<addr> anchor must already be region-relative, not the
# absolute 0x10000000+ address software actually loads/stores through.
python3 "$SCRIPT_DIR/bin2hex.py" "$IMEM_BIN" "$IMEM_HEX" --base 0x00000000
if [ -s "$DMEM_BIN" ]; then
  python3 "$SCRIPT_DIR/bin2hex.py" "$DMEM_BIN" "$DMEM_HEX" --base 0x00000000
else
  printf '@00000000\n' > "$DMEM_HEX"
fi

echo "built $NAME:"
echo "  elf:  $ELF"
echo "  dump: $DUMP"
echo "  imem: $IMEM_HEX"
echo "  dmem: $DMEM_HEX"
