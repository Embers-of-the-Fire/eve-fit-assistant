$current = Split-Path -Parent $MyInvocation.MyCommand.Definition

$native = Join-Path $current "..\rust\lib\eve-fit-os\data\out\json"
$version_file = Join-Path $current "version"
$app_data_out = Join-Path $current "out" "json"
$codegen = Join-Path $current "..\lib\native\codegen"

if (!(Test-Path $codegen)) {
    New-Item -ItemType Directory -Path $codegen -Force -ErrorAction Stop
}

Write-Host "Executing codegen..."
$uv = Get-Command -Name "uv.exe" -ErrorAction Stop
$codegen_python = Join-Path $current "codegen" "codegen.py"
& $uv run $codegen_python $native $app_data_out $version_file $codegen
