#!/usr/bin/env bash
# Verifies the development toolchain is present and reports versions.
# Invoked by `make tools`. Exits nonzero iff a tool required *right now*
# (simulation, synthesis, RISC-V toolchain) is missing. The iCE40
# place-and-route/bitstream tools are only required starting at M9, so a
# missing one is reported as a warning, not a hard failure, until then.
set -u

RISCV_PREFIX="${RISCV_PREFIX:-riscv64-unknown-elf-}"

pass=0
fail=0

first_line() { "$@" 2>&1 | grep -m1 . ; }

check_core() {
  local name="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    printf "  [ok]   %-28s %s\n" "$name" "$(first_line "$@")"
    pass=$((pass + 1))
  else
    printf "  [FAIL] %-28s not found (required)\n" "$name"
    fail=$((fail + 1))
  fi
}

check_optional() {
  local name="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    printf "  [ok]   %-28s %s\n" "$name" "$(first_line "$@")"
    pass=$((pass + 1))
  else
    printf "  [warn] %-28s not found (only required from M9 FPGA flow onward)\n" "$name"
  fi
}

echo "== Simulation =="
check_core "iverilog"  iverilog -V
check_core "vvp"       vvp -V
check_core "verilator" verilator --version

echo "== Synthesis =="
check_core "yosys" yosys -V

echo "== RISC-V toolchain (RISCV_PREFIX=$RISCV_PREFIX) =="
check_core "${RISCV_PREFIX}gcc"     "${RISCV_PREFIX}gcc"     --version
check_core "${RISCV_PREFIX}as"      "${RISCV_PREFIX}as"      --version
check_core "${RISCV_PREFIX}ld"      "${RISCV_PREFIX}ld"      --version
check_core "${RISCV_PREFIX}objdump" "${RISCV_PREFIX}objdump" --version
check_core "${RISCV_PREFIX}objcopy" "${RISCV_PREFIX}objcopy" --version

echo "== iCE40 place-and-route / bitstream flow =="
check_optional "nextpnr-ice40"  nextpnr-ice40 --version
check_optional "icepack"        icepack -h
check_optional "icetime"        icetime -h
check_optional "openFPGALoader" openFPGALoader -V

echo
echo "$pass ok, $fail missing (required)"
if [ "$fail" -gt 0 ]; then
  echo "Required tool(s) missing - see [FAIL] lines above." >&2
  exit 1
fi
exit 0
