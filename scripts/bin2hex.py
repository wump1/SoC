#!/usr/bin/env python3
"""Converts a raw binary file into a $readmemh-compatible byte-per-line hex
file, for Icarus Verilog / Verilator memory initialization.

This is a pure format conversion: one input byte becomes one two-digit hex
line, with a single leading `@<byte-address>` marker. It does not assemble,
disassemble, or interpret RISC-V instructions in any way -- that is
entirely the job of riscv64-unknown-elf-{gcc,as,ld,objcopy}, which run
before this script in scripts/build_program.sh.
"""
import argparse
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", help="raw binary file (from objcopy -O binary)")
    ap.add_argument("output", help="output $readmemh hex file")
    ap.add_argument(
        "--base",
        type=lambda x: int(x, 0),
        default=0,
        help="byte address the first byte of input is loaded at (default 0)",
    )
    args = ap.parse_args()

    with open(args.input, "rb") as f:
        data = f.read()

    with open(args.output, "w") as f:
        f.write(f"@{args.base:08x}\n")
        for b in data:
            f.write(f"{b:02x}\n")

    print(f"{args.input}: {len(data)} bytes -> {args.output} (base 0x{args.base:08x})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
