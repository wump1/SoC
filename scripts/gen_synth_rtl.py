#!/usr/bin/env python3
"""Mechanical package->`include preprocessing, for the Yosys frontend only.

Why this exists (M9 milestone note): Yosys 0.33's native `read_verilog -sv`
frontend does not support SystemVerilog `import pkg::*;` -- confirmed with
minimal repros in both module-header and module-body position, and both
fail to parse regardless of where the import appears. `sv2v` is the usual
workaround but is not available in this sandbox (no apt package; building
it from source needs a Haskell toolchain not installed here). Since every
module in this project only ever uses rv32_pkg.sv via a single, uniform
`import rv32_pkg::*;` line, a full SystemVerilog-to-Verilog converter is
not needed -- a narrow, purely mechanical, line-level substitution is
sufficient and much easier to audit than a real converter would be:

  1. rtl/core/rv32_pkg.sv's `package rv32_pkg; ... endpackage` wrapper
     lines are deleted; the remaining body (unchanged) is wrapped in an
     `ifndef/`define/`endif include guard (required because Yosys shares
     preprocessor state across every file given to one `read_verilog`
     command -- without a guard, a type/localparam included by two files
     in the same run collides as a duplicate declaration) and written to
     build/synth/rv32_pkg.svh.
  2. Every other RTL file is copied byte-for-byte into build/synth/,
     except that any line consisting *only* of `import rv32_pkg::*;`
     (whitespace aside) is deleted, and a `` `include "rv32_pkg.svh"``
     line is prepended at the top of the file.

That's the entire transform: two literal line deletions and one literal
line insertion, all done with no Verilog parsing and no semantic
reinterpretation. It relies on this project's actual, verified usage
pattern (confirmed by grep before writing this script) rather than
handling SystemVerilog in general:
  - rv32_pkg.sv is the only package in the project.
  - every import of it is the exact standalone line `import rv32_pkg::*;`.
This is intentionally not a general sv2v replacement; a codebase using
imports differently would need a different (or no) transform here.

The original rtl/ sources -- the ones every testbench simulates under
Icarus/Verilator -- are never modified; this script only ever writes to
build/synth/, and only Yosys reads that directory.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG_SRC = ROOT / "rtl/core/rv32_pkg.sv"
OUT_DIR = ROOT / "build/synth"

IMPORT_RE = re.compile(r"^\s*import\s+rv32_pkg\s*::\s*\*\s*;\s*$")


def gen_pkg_header() -> None:
    lines = PKG_SRC.read_text().splitlines()
    body = []
    for line in lines:
        stripped = line.strip()
        if stripped == "package rv32_pkg;" or stripped.startswith("endpackage"):
            continue
        body.append(line)
    out = ["`ifndef RV32_PKG_SVH", "`define RV32_PKG_SVH", "", *body, "", "`endif // RV32_PKG_SVH"]
    (OUT_DIR / "rv32_pkg.svh").write_text("\n".join(out) + "\n")


def flatten_file(src: Path) -> None:
    lines = src.read_text().splitlines()
    kept = [line for line in lines if not IMPORT_RE.match(line)]
    out = ['`include "rv32_pkg.svh"', *kept]
    (OUT_DIR / src.name).write_text("\n".join(out) + "\n")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: gen_synth_rtl.py <rtl-file.sv> [...]", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    gen_pkg_header()
    for f in argv[1:]:
        src = Path(f).resolve()
        if src == PKG_SRC:
            continue  # handled once, above, as the shared header
        flatten_file(src)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
