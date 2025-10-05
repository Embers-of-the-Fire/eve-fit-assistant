#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$xpy = Join-Path $ScriptDir "x.py"

if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Error "${PSCommandPath}: error: 'uv' not installed or not in PATH"
    exit 1
}

& uv run $xpy @args
exit $LASTEXITCODE
