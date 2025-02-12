from pathlib import Path
import sys

import patch_constant

if __name__ != "__main__":
    exit(0)

USAGE = """Usage:
    python codegen.py
        <path/to/eve-fit-os-out-json-dir>
        <path/to/output/codegen>"""

if len(sys.argv) < 3:
    print(USAGE)
    exit(1)

native_out_dir = Path(sys.argv[1])
codegen_out_dir = Path(sys.argv[2])

patch_constant.codegen(native_out_dir, codegen_out_dir)
