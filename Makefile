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

BUILD_DIR := build

.PHONY: tools clean

tools:
	@RISCV_PREFIX=$(RISCV_PREFIX) scripts/check_tools.sh

clean:
	rm -rf $(BUILD_DIR) fpga/build/*
	find sw -name '*.elf' -o -name '*.o' -o -name '*.dump' -o -name '*.hex' | xargs -r rm -f
	find synth -maxdepth 1 -name '*.json' -o -name '*.log' | xargs -r rm -f
