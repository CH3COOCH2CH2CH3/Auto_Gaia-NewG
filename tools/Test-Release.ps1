#requires -version 5.1

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $RepoRoot "release\version.json"

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "release\version.json was not found."
}

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$ScriptPath = Join-Path (Join-Path $RepoRoot "release") ([string]$Manifest.script)

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw ("Release script not found: " + $ScriptPath)
}

$ActualSize = [int64](Get-Item -LiteralPath $ScriptPath).Length
$Actual = (Get-FileHash -LiteralPath $ScriptPath -Algorithm SHA256).Hash.ToUpperInvariant()
$Expected = ([string]$Manifest.sha256).ToUpperInvariant()

Write-Host ("Version : " + $Manifest.version)
Write-Host ("Build   : " + $Manifest.build)
Write-Host ("Ready   : " + $Manifest.ready)
Write-Host ("Size    : " + $ActualSize + " bytes")
Write-Host ("Expected: " + $Expected)
Write-Host ("Actual  : " + $Actual)

if ($Manifest.size -and $ActualSize -ne [int64]$Manifest.size) {
    throw "File size mismatch."
}

if ($Actual -ne $Expected) {
    throw "SHA256 mismatch."
}

Write-Host ""
Write-Host "Local release validation passed." -ForegroundColor Green
