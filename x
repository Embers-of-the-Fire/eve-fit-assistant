#!/bin/sh
set -eu

# 获取当前脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XPY="$SCRIPT_DIR/x.py"

# 检查 uv 是否可用
if ! command -v uv >/dev/null 2>&1; then
    echo "$0: error: 'uv' not installed or not in PATH" >&2
    exit 1
fi

exec uv run "$XPY" "$@"
