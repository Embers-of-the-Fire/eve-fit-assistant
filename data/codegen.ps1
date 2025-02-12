$current = Split-Path -Parent $MyInvocation.MyCommand.Definition

$native = Join-Path $current "..\rust\lib\eve-fit-os\data\out\json"
$codegen = Join-Path $current "..\lib\native\codegen"

if (!(Test-Path $codegen)) {
    New-Item -ItemType Directory -Path $codegen -Force -ErrorAction Stop
}

Write-Host "Executing codegen..."
$uv = Get-Command -Name "uv.exe" -ErrorAction Stop
$codegen_python = Join-Path $current "codegen" "codegen.py"
& $uv run $codegen_python $native $codegen
