from pathlib import Path
import sys

import patch_constant
import version

if __name__ != "__main__":
    exit(0)

USAGE = """Usage:
    python codegen.py
        <path/to/eve-fit-os-out-json-dir>
        <path/to/bundle/version-file>
        <path/to/output/codegen>"""

if len(sys.argv) < 4:
    print(USAGE)
    exit(1)

native_out_dir = Path(sys.argv[1])
bundle_version_file = Path(sys.argv[2])
codegen_out_dir = Path(sys.argv[3])

patch_constant.codegen(native_out_dir, bundle_version_file, codegen_out_dir)
version.codegen(native_out_dir, bundle_version_file, codegen_out_dir)
