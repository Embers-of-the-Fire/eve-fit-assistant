from pathlib import Path
import sys

import patch_constant
import version
import units

if __name__ != "__main__":
    exit(0)

USAGE = """Usage:
    python codegen.py
        <path/to/eve-fit-os-out-json-dir>
        <path/to/eve-fit-assistant-out-json-dir>
        <path/to/bundle/version-file>
        <path/to/output/codegen>"""

if len(sys.argv) != 5:
    print(USAGE)
    exit(1)

native_out_dir = Path(sys.argv[1])
app_out_dir = Path(sys.argv[2])
bundle_version_file = Path(sys.argv[3])
codegen_out_dir = Path(sys.argv[4])

patch_constant.codegen(native_out_dir, app_out_dir, bundle_version_file, codegen_out_dir)
version.codegen(native_out_dir, app_out_dir, bundle_version_file, codegen_out_dir)
units.codegen(native_out_dir, app_out_dir, bundle_version_file, codegen_out_dir)
