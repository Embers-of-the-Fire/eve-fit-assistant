$original = Get-Location

Write-Host "Running routine tasks..."
try {
    $current = Split-Path -Parent $MyInvocation.MyCommand.Definition

    & (Join-Path $current "compile.ps1")
    & (Join-Path $current "convert.ps1")
    & (Join-Path $current "bundle.ps1")
    & (Join-Path $current "codegen.ps1")
}
finally {
    Set-Location $original
}
