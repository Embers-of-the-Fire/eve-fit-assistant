param (
    [switch] $Native
)

$original = Get-Location

try {
    $current = Split-Path -Parent $MyInvocation.MyCommand.Definition
    
    Set-Location -Path $current
    
    $fsd_dir = Join-Path $current "fsd"
    if (!(Test-Path $fsd_dir)) {
        Write-Output 'Cannot find `fsd` directory'
        Exit-PSSession
    }
    $fsd_loc_dir = Join-Path $current "fsd-localization"
    $out_dir = Join-Path $current "out"

    if (!$Native) {
        Write-Host "Cleaning up previous conversion..."
        Remove-Item -Path $out_dir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    $index_path = Join-Path $current "resfileindex.txt"
    $index_cache = Join-Path $current "index-cache"
    $patches = Join-Path $current "patches"

    $uv = Get-Command -Name "uv.exe" -ErrorAction Stop
    $convert_dir = Join-Path $current "convert"
    $convert_script = Join-Path $convert_dir "run.py"
    
    if (!$Native) {
        & $uv run $convert_script $fsd_dir $index_path $patches $out_dir $index_cache
    }
    
    Write-Host 'Executing `eve-fit-os` converters...'
    
    $eve_fit_os_dir = Join-Path $current "..\rust\lib\eve-fit-os"
    Set-Location $eve_fit_os_dir
    $eve_fit_os_dir = (Get-Location).Path
    $fit_os_out_dir = Join-Path $eve_fit_os_dir "data" "out"
    $patch_dir = Join-Path $eve_fit_os_dir "data" "patches"
    $fsd_patch_dir = Join-Path $eve_fit_os_dir "data" "fsd-patches"
    $fsd_loc_en = Join-Path $fsd_loc_dir "localization_fsd_en-us.pickle"
    & $uv run -m data.convert $fsd_dir $fsd_loc_en $fsd_patch_dir $patch_dir $fit_os_out_dir
}
finally {
    Set-Location $original
}
