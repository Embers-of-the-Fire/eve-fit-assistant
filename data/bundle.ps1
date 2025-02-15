param (
    [switch] $ClearCache,
    [switch] $Download
)

$current = Split-Path -Parent $MyInvocation.MyCommand.Definition
$pb2_dir = Join-Path $current "out" "pb2"
$tar = Get-Command -Name "tar.exe" -ErrorAction Stop

$cache_dir = Join-Path $current "cache"

if ($ClearCache) {
    Write-Host "Clearing cache directory $cache_dir"
    Remove-Item -Path $cache_dir -Recurse -Force -ErrorAction SilentlyContinue
}

$version_file = Join-Path $cache_dir "version"
New-Item -ItemType Directory -Force -Path $cache_dir | Out-Null
Copy-Item -Path (Join-Path $pb2_dir "*") -Destination $cache_dir -Recurse -Force
New-Item -ItemType File -Force -Path $version_file | Out-Null
$time = Get-Date -UFormat %s
Write-Host "Creating version timestamp at $time"
Set-Content -Path $version_file -Value $time -Force
Copy-Item -Path $version_file -Destination $current

Write-Host "Executing extra python commands"
$uv = Get-Command -Name "uv.exe" -ErrorAction Stop
$bundle_python = Join-Path $current "bundle" "extra.py"
$fsd_dir = Join-Path $current "fsd"
$image_dir = Join-Path $current "images"
$index_file = Join-Path $current "resfileindex.txt"
if ($Download) {
    & $uv run $bundle_python $fsd_dir $image_dir $index_file $cache_dir --download
} else {
    & $uv run $bundle_python $fsd_dir $image_dir $index_file $cache_dir
}

Write-Host 'Copying `eve-fit-os` native data...'
$eve_fit_os_out_dir = Join-Path $current "..\rust\lib\eve-fit-os\data\out\pb2"
$native_cache_dir = Join-Path $cache_dir "native"
New-Item -ItemType Directory -Force -Path $native_cache_dir | Out-Null
Copy-Item -Path (Join-Path $eve_fit_os_out_dir "dogmaAttributes.pb2") -Destination $native_cache_dir -Recurse -Force
Copy-Item -Path (Join-Path $eve_fit_os_out_dir "dogmaEffects.pb2") -Destination $native_cache_dir -Recurse -Force
Copy-Item -Path (Join-Path $eve_fit_os_out_dir "typeDogma.pb2") -Destination $native_cache_dir -Recurse -Force
Copy-Item -Path (Join-Path $eve_fit_os_out_dir "types.pb2") -Destination $native_cache_dir -Recurse -Force

Write-Host "Creating tarball ..."
$tarball = Join-Path $current "storage.tar.gz"
& $tar -czf $tarball -C $cache_dir .
Write-Host "Tarball created at $tarball"
