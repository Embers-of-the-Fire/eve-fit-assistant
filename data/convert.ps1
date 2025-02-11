$current = Split-Path -Parent $MyInvocation.MyCommand.Definition

Set-Location -Path $current

$fsd_dir = Join-Path $current "fsd"
if (!(Test-Path $fsd_dir)) {
    Write-Output 'Cannot find `fsd` directory'
    Exit-PSSession
}
$out_dir = Join-Path $current "out"

$uv = Get-Command -Name "uv.exe" -ErrorAction Stop
$convert_dir = Join-Path $current "convert"
$convert_script = Join-Path $convert_dir "run.py"
& $uv run $convert_script $fsd_dir $out_dir
