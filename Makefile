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

BUILD_DIR    := build
BUILD_SIM    := $(BUILD_DIR)/sim
BUILD_PROG   := $(BUILD_DIR)/programs

RTL_BASE := rtl/core/rv32_pkg.sv rtl/core/pc.sv rtl/core/regfile.sv rtl/core/alu.sv \
            rtl/core/branch_unit.sv rtl/core/imm_gen.sv rtl/core/load_store_unit.sv \
            rtl/core/decoder.sv rtl/core/hazard_unit.sv rtl/core/forward_unit.sv
RTL_SINGLE := $(RTL_BASE) rtl/core/rv32_single.sv
RTL_PIPE   := $(RTL_BASE) rtl/pipeline/pipe_if_id.sv rtl/pipeline/pipe_id_ex.sv \
              rtl/pipeline/pipe_ex_mem.sv rtl/pipeline/pipe_mem_wb.sv rtl/pipeline/rv32_core.sv

# make program PROGRAM=sw/asm/loop.S / make dump PROGRAM=sw/asm/loop.S
PROGRAM ?=

.PHONY: tools clean lint unit sim test program dump wave

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

clean:
	rm -rf $(BUILD_DIR) fpga/build/*
	find sw -name '*.elf' -o -name '*.o' -o -name '*.dump' -o -name '*.hex' | xargs -r rm -f
	find synth -maxdepth 1 -name '*.json' -o -name '*.log' | xargs -r rm -f
