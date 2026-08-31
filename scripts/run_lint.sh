#!/usr/bin/env bash
# Verilator --lint-only over every synthesizable core module, both cores'
# full integration, -Wall. A handful of specific, individually-documented
# warnings are filtered as known-benign (see the grep patterns below for
# exactly which, and rtl/core/rv32_single.sv / rtl/pipeline/rv32_core.sv
# for why); anything else is real and must stay clean.
set -uo pipefail

# UNUSEDPARAM: an artifact of linting each module standalone against the
#   shared rv32_pkg.sv -- only a subset of the package's constants apply
#   to any one module.
# imem_ready/dmem_ready unused: the zero-wait-state baseline (Section 5)
#   doesn't check them yet; the ports exist for the interface contract.
# opcode/funct3/funct7 PINCONNECTEMPTY: decoder outputs kept for
#   tb_decoder.sv's standalone unit testing; the datapath only needs
#   rd/rs1/rs2 and control_t (which already carries funct3).
# instr[6:0] unused in imm_gen: it doesn't need the opcode field.
# trace/dbg_illegal/dbg_misaligned unused in soc_top: debug-only, reached
#   by hierarchical reference from testbenches, never wired to a port.
# ram_ready unused in address_decoder: same zero-wait-state reasoning as
#   imem_ready/dmem_ready above.
# addr[...] bits unused in imem/dmem: high bits already consumed by
#   address_decoder's region select; low 2 bits/wstrb (not addr) pick the
#   byte lane.
# wdata[31:8] unused in gpio: GPIO_WIDTH=8, a store's upper bits are
#   simply discarded.
BENIGN_PATTERN="UNUSEDPARAM\
|Signal is not used: 'imem_ready'|Signal is not used: 'dmem_ready'\
|Cell pin connected by name with empty reference: 'opcode'\
|Cell pin connected by name with empty reference: 'funct3'\
|Cell pin connected by name with empty reference: 'funct7'\
|Bits of signal are not used: 'instr'\[6:0\]\
|Signal is not used: 'trace'|Signal is not used: 'dbg_illegal'|Signal is not used: 'dbg_misaligned'\
|Signal is not used: 'ram_ready'|Signal is not used: 'req'\
|Bits of signal are not used: 'addr'\
|Bits of signal are not used: 'wdata'\[31:8\]"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERILATOR="${VERILATOR:-verilator}"
RTL_BASE="rtl/core/rv32_pkg.sv rtl/core/pc.sv rtl/core/regfile.sv rtl/core/alu.sv
          rtl/core/branch_unit.sv rtl/core/imm_gen.sv rtl/core/load_store_unit.sv
          rtl/core/decoder.sv rtl/core/hazard_unit.sv rtl/core/forward_unit.sv"
RTL_SINGLE="$RTL_BASE rtl/core/rv32_single.sv"
RTL_PIPE="$RTL_BASE rtl/pipeline/pipe_if_id.sv rtl/pipeline/pipe_id_ex.sv
           rtl/pipeline/pipe_ex_mem.sv rtl/pipeline/pipe_mem_wb.sv rtl/pipeline/rv32_core.sv"
RTL_SOC="$RTL_PIPE rtl/soc/imem.sv rtl/soc/dmem.sv rtl/soc/gpio.sv rtl/soc/uart_tx.sv
         rtl/soc/reset_sync.sv rtl/soc/address_decoder.sv rtl/soc/soc_top.sv"

fail=0

lint_one() {
  local top="$1"
  shift
  echo "== $top =="
  local out
  out="$("$VERILATOR" --lint-only -Wall --top-module "$top" "$@" 2>&1)"
  local real
  real="$(echo "$out" | grep -E '%Error|%Warning' | grep -v '%Error: Exiting due to' | grep -vE "$BENIGN_PATTERN" || true)"
  if [ -n "$real" ]; then
    echo "$real"
    fail=1
  else
    echo "  clean (only documented-benign warnings filtered, if any)"
  fi
}

lint_one rv32_single $RTL_SINGLE
lint_one rv32_core $RTL_PIPE
lint_one soc_top $RTL_SOC

if [ "$fail" -ne 0 ]; then
  echo "lint: FAILED -- see undocumented warnings/errors above" >&2
  exit 1
fi
echo "lint: clean"
exit 0
