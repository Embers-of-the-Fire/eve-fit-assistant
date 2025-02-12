$current = Split-Path -Parent $MyInvocation.MyCommand.Definition
$schema_dir = Join-Path $current "schema"
$protoc = Get-Command -Name "protoc.exe" -ErrorAction Stop

$python_convert_dir = Join-Path $current "convert"
$dart_convert_dir = Join-Path (Split-Path -Parent $current) "lib" "storage" "proto"

Write-Host "Clearing previous generated files ..."
$files_to_delete = Get-ChildItem -Path (Join-Path $current "convert") -Filter "*_pb2.py" -Recurse -File
foreach ($file in $files_to_delete) {
    Write-Host "Deleting $file ..."
    Remove-Item $file.FullName
}
if (Test-Path $dart_convert_dir) {
    Write-Host "Deleting $dart_convert_dir ..."
    Remove-Item -Path $dart_convert_dir -Recurse -Force
}
New-Item -Path $dart_convert_dir -ItemType Directory | Out-Null

foreach ($file in Get-ChildItem -Path $schema_dir -Filter *.proto) {
    $name = $file.Name;
    $source = Join-Path $schema_dir $name;
    Write-Host "Compiling $source ..."
    & $protoc -I $schema_dir --python_out $python_convert_dir --dart_out $dart_convert_dir $source
}
