#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

# 获取脚本目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$xpy = Join-Path $ScriptDir "x.py"

# 检查 uv 是否可用
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Error "${PSCommandPath}: error: 'uv' not installed or not in PATH"
    exit 1
}

# 传递参数
& uv run $xpy @args
exit $LASTEXITCODE
