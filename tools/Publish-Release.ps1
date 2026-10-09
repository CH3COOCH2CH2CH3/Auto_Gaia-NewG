#requires -version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [switch]$AllowPlaceholder
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ReleaseDir = Join-Path $RepoRoot "release"
$ScriptPath = Join-Path $ReleaseDir "Deploy-Education.ps1"
$ManifestPath = Join-Path $ReleaseDir "version.json"

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "release\Deploy-Education.ps1 was not found."
}

$ScriptText = Get-Content -LiteralPath $ScriptPath -Raw

$ApiKeyMatch = [regex]::Match(
    $ScriptText,
    '(?m)^\s*\$ApiKey\s*=\s*"([^"]*)"\s*$'
)

if (-not $ApiKeyMatch.Success) {
    throw "Could not locate the `$ApiKey assignment in Deploy-Education.ps1."
}

$ConfiguredApiKey = $ApiKeyMatch.Groups[1].Value

if (
    -not $AllowPlaceholder -and
    (
        [string]::IsNullOrWhiteSpace($ConfiguredApiKey) -or
        $ConfiguredApiKey -eq "PASTE_YOUR_GOOGLE_DRIVE_API_KEY_HERE"
    )
) {
    throw (
        "Deploy-Education.ps1 does not contain a configured Google Drive API key. " +
        "Replace the placeholder before publishing, or use -AllowPlaceholder " +
        "only for a deliberate non-production test."
    )
}

$Hash = (Get-FileHash -LiteralPath $ScriptPath -Algorithm SHA256).Hash.ToUpperInvariant()

$Size = [int64](Get-Item -LiteralPath $ScriptPath).Length

$Build = ""
$BuildMatch = [regex]::Match(
    $ScriptText,
    '(?m)^# Build:\s*(.+)$'
)

if ($BuildMatch.Success) {
    $Build = $BuildMatch.Groups[1].Value.Trim()
}

$Manifest = [ordered]@{
    schema      = 1
    version     = $Version
    build       = $Build
    script      = "Deploy-Education.ps1"
    size        = $Size
    sha256      = $Hash
    publishedAt = [DateTimeOffset]::Now.ToString("o")
    ready       = $true
}

$Json = $Manifest | ConvertTo-Json -Depth 4

[System.IO.File]::WriteAllText(
    $ManifestPath,
    ($Json + [Environment]::NewLine),
    [System.Text.Encoding]::ASCII
)

Write-Host ""
Write-Host "Release manifest updated." -ForegroundColor Green
Write-Host ("Version : " + $Version)
Write-Host ("Build   : " + $Build)
Write-Host ("Size    : " + $Size + " bytes")
Write-Host ("SHA256  : " + $Hash)
Write-Host ""
Write-Host "Next:"
Write-Host "  git add release/Deploy-Education.ps1 release/version.json"
Write-Host ('  git commit -m "release ' + $Version + '"')
Write-Host "  git push"
