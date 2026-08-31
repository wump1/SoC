# RV32I RISC-V processor project.
# See README.md for an overview and docs/ for the design contract.
#
# RISCV_PREFIX isolates the one real difference between this sandbox and a
# developer's own machine (e.g. Homebrew on macOS installs riscv64-elf-*,
# apt on Ubuntu installs riscv64-unknown-elf-*). Override on the command
# line or environment: `make RISCV_PREFIX=riscv64-elf- test`.
RISCV_PREFIX ?= riscv64-unknown-elf-

CC      := $(RISCV_PREFIX)gcc
AS      := $(RISCV_PREFIX)as
LD      := $(RISCV_PREFIX)ld
OBJDUMP := $(RISCV_PREFIX)objdump
OBJCOPY := $(RISCV_PREFIX)objcopy

IVERILOG := iverilog
VVP      := vvp
VERILATOR := verilator
YOSYS    := yosys
NEXTPNR  := nextpnr-ice40
ICETIME  := icetime
ICEPACK  := icepack

BUILD_DIR    := build
BUILD_SIM    := $(BUILD_DIR)/sim
BUILD_PROG   := $(BUILD_DIR)/programs
BUILD_SYNTH  := $(BUILD_DIR)/synth
SYNTH_DIR    := synth

RTL_BASE := rtl/core/rv32_pkg.sv rtl/core/pc.sv rtl/core/regfile.sv rtl/core/alu.sv \
            rtl/core/branch_unit.sv rtl/core/imm_gen.sv rtl/core/load_store_unit.sv \
            rtl/core/decoder.sv rtl/core/hazard_unit.sv rtl/core/forward_unit.sv
RTL_SINGLE := $(RTL_BASE) rtl/core/rv32_single.sv
RTL_PIPE   := $(RTL_BASE) rtl/pipeline/pipe_if_id.sv rtl/pipeline/pipe_id_ex.sv \
              rtl/pipeline/pipe_ex_mem.sv rtl/pipeline/pipe_mem_wb.sv rtl/pipeline/rv32_core.sv
RTL_SOC    := $(RTL_PIPE) rtl/soc/imem.sv rtl/soc/dmem.sv rtl/soc/gpio.sv rtl/soc/uart_tx.sv \
              rtl/soc/reset_sync.sv rtl/soc/address_decoder.sv rtl/soc/soc_top.sv

# make program PROGRAM=sw/asm/loop.S / make dump PROGRAM=sw/asm/loop.S
PROGRAM ?=

.PHONY: tools clean lint unit sim test program dump wave \
        synth synth-soc-smoketest pnr timing bitstream fpga-program

tools:
	@RISCV_PREFIX=$(RISCV_PREFIX) scripts/check_tools.sh

lint:
	@scripts/run_lint.sh

unit:
	@scripts/run_tests.sh unit

sim:
	@scripts/run_tests.sh core

test:
	@scripts/run_tests.sh all

program:
	@if [ -z "$(PROGRAM)" ]; then echo "usage: make program PROGRAM=sw/asm/<name>.S"; exit 1; fi
	@mkdir -p $(BUILD_PROG)
	@RISCV_PREFIX=$(RISCV_PREFIX) scripts/build_program.sh $(PROGRAM) $(BUILD_PROG)

dump: program
	@cat $(BUILD_PROG)/$$(basename $(PROGRAM) .S).dump

# Dumps dut.* (the CPU instance) to a VCD for one representative program,
# on the pipeline by default: make wave PROGRAM=sw/asm/loop.S
# [DUT=rv32_single|rv32_core].
DUT ?= rv32_core
wave: program
	@mkdir -p $(BUILD_SIM)
	@name=$$(basename $(PROGRAM) .S); \
	vcd=$(BUILD_SIM)/$$name.$(DUT).vcd; \
	iverilog -g2012 -DCORE_DUT=$(DUT) -DDUMP_VCD=1 -DVCD_FILE=\"$$vcd\" \
	  -DTEST_IMEM_HEX=\"$(BUILD_PROG)/$$name.imem.hex\" -DTEST_DMEM_HEX=\"$(BUILD_PROG)/$$name.dmem.hex\" \
	  -I tb/common -I tb/core -o $(BUILD_SIM)/wave_$$name.vvp \
	  $(if $(filter rv32_single,$(DUT)),$(RTL_SINGLE),$(RTL_PIPE)) \
	  tb/common/sram_model.sv tb/core/tb_$$name.sv; \
	vvp $(BUILD_SIM)/wave_$$name.vvp; \
	echo "wrote $$vcd"

# M9 (see docs/fpga.md): Yosys 0.33's frontend cannot parse this project's
# `import rv32_pkg::*;` at all -- scripts/gen_synth_rtl.py mechanically
# rewrites *copies* of the RTL into $(BUILD_SYNTH) for every synth target
# below; the rtl/ sources every testbench simulates are never touched.
$(BUILD_SYNTH)/.stamp: $(RTL_SOC) scripts/gen_synth_rtl.py
	@mkdir -p $(BUILD_SYNTH) $(SYNTH_DIR)/reports
	@python3 scripts/gen_synth_rtl.py $(RTL_SOC)
	@touch $@

# The real, always-clean synthesis target: rv32_core (the CPU itself) has
# no internal memory arrays -- imem/dmem are external ports -- so it maps
# completely to real iCE40 cells with no caveats. This is the meaningful
# utilization number for "the processor"; see docs/fpga.md for why the
# full soc_top (below) needs a downsized memory to synthesize at all.
synth: $(BUILD_SYNTH)/.stamp
	$(YOSYS) -p "\
	  read_verilog -sv $(addprefix $(BUILD_SYNTH)/,$(filter-out rv32_pkg.sv,$(notdir $(RTL_PIPE)))); \
	  hierarchy -top rv32_core; \
	  synth_ice40 -top rv32_core -json $(SYNTH_DIR)/rv32_core.json; \
	" 2>&1 | tee $(SYNTH_DIR)/reports/rv32_core_synth.log

# Full SoC, with IMEM/DMEM downsized (via `chparam`, not an RTL edit) to
# fit iCE40UP5K's ~5280-LC budget as flip-flop-based storage. This is a
# genuine, complete synth+PnR+timing proof that the top-level SoC design
# (CPU + address decoder + GPIO + UART TX + reset sync) fits and routes on
# the target device -- NOT the real 64KB memory map from docs/memory_map.md,
# which docs/fpga.md documents as needing a registered-read memory redesign
# before it can map to real block RAM/SPRAM primitives at all.
SMOKETEST_PROGRAM  ?= sw/asm/uart_hello.S
SMOKETEST_IMEM_BITS ?= 7
SMOKETEST_DMEM_BITS ?= 5
synth-soc-smoketest: $(BUILD_SYNTH)/.stamp
	@$(MAKE) --no-print-directory program PROGRAM=$(SMOKETEST_PROGRAM)
	$(YOSYS) -p "\
	  read_verilog -sv $(addprefix $(BUILD_SYNTH)/,$(filter-out rv32_pkg.sv,$(notdir $(RTL_SOC)))); \
	  chparam -set IMEM_ADDR_WIDTH $(SMOKETEST_IMEM_BITS) -set DMEM_ADDR_WIDTH $(SMOKETEST_DMEM_BITS) soc_top; \
	  hierarchy -top soc_top; \
	  synth_ice40 -top soc_top -json $(SYNTH_DIR)/soc_top_smoketest.json; \
	" 2>&1 | tee $(SYNTH_DIR)/reports/soc_top_smoketest_synth.log

# Unconstrained (no .pcf -- no board confirmed yet, see README/docs/fpga.md):
# nextpnr auto-places every I/O pad with no knowledge of what's physically
# wired to it on any real board. Proves the design fits/routes on an
# iCE40UP5K and gives a real Fmax; the result must never be programmed onto
# hardware (see `bitstream` below).
pnr: synth-soc-smoketest
	$(NEXTPNR) --up5k --json $(SYNTH_DIR)/soc_top_smoketest.json \
	  --asc $(SYNTH_DIR)/soc_top_smoketest.asc \
	  --report $(SYNTH_DIR)/reports/soc_top_smoketest_pnr_report.json \
	  2>&1 | tee $(SYNTH_DIR)/reports/soc_top_smoketest_pnr.log

timing: pnr
	$(ICETIME) -d up5k -t -r $(SYNTH_DIR)/reports/soc_top_smoketest_timing.rpt \
	  $(SYNTH_DIR)/soc_top_smoketest.asc | tee $(SYNTH_DIR)/reports/soc_top_smoketest_timing.log

# UNCONSTRAINED bitstream -- proves the synth->pnr->bitstream tool flow
# completes end to end. Do NOT program this onto real hardware: its I/O
# pins were placed with no pin constraints at all (see `pnr` above), so
# they carry no relationship to any real board's wiring and could drive
# pins the board depends on (e.g. SPI flash) into conflict.
bitstream: pnr
	$(ICEPACK) $(SYNTH_DIR)/soc_top_smoketest.asc $(SYNTH_DIR)/soc_top_smoketest.bin
	@echo "wrote $(SYNTH_DIR)/soc_top_smoketest.bin -- UNCONSTRAINED, proof-of-flow only, DO NOT program onto real hardware (see docs/fpga.md)"

fpga-program:
	@echo "fpga-program: refusing to run."
	@echo "  No FPGA board has been confirmed for this project yet (see README.md / docs/fpga.md)."
	@echo "  No .pcf pin-constraint file exists, and one must never be guessed."
	@echo "  This sandbox also has no USB/hardware access to program a device."
	@echo "  See docs/fpga.md for the physical bring-up procedure to run on real hardware"
	@echo "  once the exact board model/revision is confirmed."
	@exit 1

clean:
	rm -rf $(BUILD_DIR) fpga/build/*
	find sw -name '*.elf' -o -name '*.o' -o -name '*.dump' -o -name '*.hex' | xargs -r rm -f
	find $(SYNTH_DIR) -maxdepth 1 -type f | xargs -r rm -f
	rm -rf $(SYNTH_DIR)/reports/*
