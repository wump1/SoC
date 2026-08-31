#!/usr/bin/env bash
# Full regression: builds every program under sw/asm/, runs every unit
# testbench, then every core-level directed-program testbench against
# BOTH rv32_single and rv32_core (core_harness.svh's `CORE_DUT macro
# picks the DUT; rv32_single and rv32_core share an identical port list,
# so the exact same testbench source drives either one). Auto-discovers
# test files rather than hardcoding a list, so a new tb_*.sv or sw/asm/*.S
# is picked up automatically.
#
# Prints a pass/fail line per test and a final summary, and -- this is
# the part `make test` actually depends on -- exits nonzero if anything
# failed to compile or any TESTBENCH_RESULT was not PASS.
#
# Usage: scripts/run_tests.sh [unit|core|all]   (default: all)
#   unit -- tb/unit/ only, no program builds needed.
#   core -- sw/asm/ programs + tb/core/ against both DUTs.
#   all  -- both of the above (this is what `make test` runs).
set -uo pipefail

MODE="${1:-all}"
case "$MODE" in
  unit|core|all) ;;
  *) echo "usage: $0 [unit|core|all]" >&2; exit 1 ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BUILD_SIM="build/sim"
BUILD_PROG="build/programs"
mkdir -p "$BUILD_SIM" "$BUILD_PROG"

RTL_BASE="rtl/core/rv32_pkg.sv rtl/core/pc.sv rtl/core/regfile.sv rtl/core/alu.sv
          rtl/core/branch_unit.sv rtl/core/imm_gen.sv rtl/core/load_store_unit.sv
          rtl/core/decoder.sv rtl/core/hazard_unit.sv rtl/core/forward_unit.sv"
RTL_SINGLE="$RTL_BASE rtl/core/rv32_single.sv"
RTL_PIPE="$RTL_BASE rtl/pipeline/pipe_if_id.sv rtl/pipeline/pipe_id_ex.sv
           rtl/pipeline/pipe_ex_mem.sv rtl/pipeline/pipe_mem_wb.sv rtl/pipeline/rv32_core.sv"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_TESTS=()

# run_one <label> <vvp_out_path> <iverilog args...>
run_one() {
  local label="$1" vvp_out="$2"
  shift 2
  iverilog -g2012 -I tb/common -I tb/core -o "$vvp_out" "$@" >"$vvp_out.compile.log" 2>&1
  if [ ! -f "$vvp_out" ]; then
    echo "  [FAIL] $label -- COMPILE ERROR, see $vvp_out.compile.log"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS+=("$label (compile error)")
    return
  fi
  local result
  result="$(timeout 60 vvp "$vvp_out" 2>/dev/null | grep "TESTBENCH_RESULT")"
  if [ -z "$result" ]; then
    echo "  [FAIL] $label -- no TESTBENCH_RESULT line (crashed or timed out)"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS+=("$label (no result)")
    return
  fi
  echo "  $result"
  if echo "$result" | grep -q "TESTBENCH_RESULT: PASS"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_TESTS+=("$label")
  fi
}

if [ "$MODE" = "unit" ] || [ "$MODE" = "all" ]; then
  echo "== Unit tests =="
  for tb in tb/unit/tb_*.sv; do
    name="$(basename "${tb%.*}")"
    run_one "$name" "$BUILD_SIM/$name.vvp" $RTL_BASE "$tb"
  done
fi

if [ "$MODE" = "core" ] || [ "$MODE" = "all" ]; then
  echo "== Building sw/asm/ programs =="
  for src in sw/asm/*.S; do
    name="$(basename "${src%.*}")"
    extra_env=()
    [ "$name" = "illegal_safety" ] && extra_env=(ALLOW_ILLEGAL=1)
    if ! env "${extra_env[@]}" ./scripts/build_program.sh "$src" "$BUILD_PROG" >"$BUILD_PROG/$name.build.log" 2>&1; then
      echo "  [FAIL] build $name -- see $BUILD_PROG/$name.build.log"
      TOTAL_FAIL=$((TOTAL_FAIL + 1))
      FAILED_TESTS+=("build $name")
    else
      echo "  [ok]   build $name"
    fi
  done

  echo "== Core tests: rv32_single =="
  for tb in tb/core/tb_*.sv; do
    name="$(basename "${tb%.*}")"
    run_one "$name [single-cycle]" "$BUILD_SIM/sc_$name.vvp" $RTL_SINGLE tb/common/sram_model.sv "$tb"
  done

  echo "== Core tests: rv32_core (pipeline) =="
  for tb in tb/core/tb_*.sv; do
    name="$(basename "${tb%.*}")"
    run_one "$name [pipeline]" "$BUILD_SIM/pipe_$name.vvp" -DCORE_DUT=rv32_core $RTL_PIPE tb/common/sram_model.sv "$tb"
  done
fi

echo "==================================="
echo "TOTAL: $TOTAL_PASS passed, $TOTAL_FAIL failed"
if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo "Failed:"
  printf '  - %s\n' "${FAILED_TESTS[@]}"
  exit 1
fi
exit 0
