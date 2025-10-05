#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XPY="$SCRIPT_DIR/x.py"

if ! command -v uv >/dev/null 2>&1; then
    echo "$0: error: 'uv' not installed or not in PATH" >&2
    exit 1
fi

exec uv run "$XPY" "$@"
