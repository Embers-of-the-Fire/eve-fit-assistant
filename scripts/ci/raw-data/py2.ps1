param(
    [string]$ZipPath = "tools/eve-fsd-dumper/py27.zip",
    [string]$ExtractPath = "py27"
)

if (!(Test-Path $ZipPath)) {
    Write-Error "Python 2.7 archive not found: $ZipPath"
    exit 1
}

if (!(Test-Path $ExtractPath)) {
    Write-Host "Extracting portable Python 2.7 to $ExtractPath ..."
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath
} else {
    Write-Host "Python 2.7 already extracted at $ExtractPath."
}

$pythonExe = Join-Path $ExtractPath "python.exe"
if (!(Test-Path $pythonExe)) {
    Write-Error "python.exe not found in $ExtractPath"
    exit 1
}

Write-Host "Python 2.7 executable: $pythonExe"
