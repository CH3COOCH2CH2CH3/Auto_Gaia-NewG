#requires -version 5.1

$ErrorActionPreference = "Stop"

# ============================================================
# EDUCATION SOFTWARE DEPLOYMENT
# Windows 10 / Windows 11
# Build: v7 - direct mode credential handoff + v6 readiness
#
# IMPORTANT:
# Replace the API key below before distributing this script.
# The source file intentionally uses ASCII only.
# ============================================================

$ApiKey = "AIzaSyATEOhFrIeqzmXPNHKr58JYt9P38A4SlPc"
$DriveFolderId = "1Ew9e3nHfiGOEnv9QTqY1Qb6zcJQXb9ZD"

$TargetClientWidth  = 984
$TargetClientHeight = 661

$UsernameX = 0.50
$UsernameY = 0.44
$PasswordX = 0.50
$PasswordY = 0.59
$LoginX    = 0.69
$LoginY    = 0.78

$VisualChangeThreshold = 25.0
$VisualRequiredHits    = 2
$VisualTimeoutSeconds  = 20
$VisualSampleStep      = 16
$PixelDifferenceLimit  = 90

# Login-page readiness detection.
# The login button is large and orange in both NEWG and GAIA. The script
# waits until that button region is detected in two consecutive captures
# before sending any keyboard or mouse input.
$LoginReadyTimeoutSeconds   = 60
$LoginReadyPollMs           = 500
$LoginReadyRequiredHits     = 2
$LoginReadyGraceMs          = 1000
$LoginReadySampleStep       = 3
$LoginReadyOrangeMinPercent = 1.5
$LoginReadyLightMinPercent  = 25.0
$LoginReadyBlueMinPercent   = 8.0

$InstallNoticeBase64 = "RW0gxJFhbmcgY8OgaSDEkeG6t3QgcGjhuqduIG3hu4FtIGNobyB0aOG6p3kvY8O0IOG6oS4KTW9uZyB0aOG6p3kvY8O0IGNobyBlbSB4aW4gw610IHBow7p0IHbDoCB0cm9uZyBsw7pjIG7DoHkgeGluIMSR4burbmcgdGhhbyB0w6FjIG3DoXkg4bqhLg=="
$SuccessNoticeBase64 = "Q8OgaSDEkeG6t3QgxJHDoyBob8OgbiB04bqldCB0aMOgbmggY8O0bmcuClRo4bqneS9jw7QgY8OzIHRo4buDIHPhu60gZOG7pW5nIG3DoXkgYsOsbmggdGjGsOG7nW5nLg=="
$FailureNoticeBase64 = "Q8OgaSDEkeG6t3QgY2jGsGEgaG/DoG4gdOG6pXQuClZ1aSBsw7JuZyBsacOqbiBo4buHIG5nxrDhu51pIGjhu5cgdHLhu6Mu"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Stop-Deploy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    throw $Message
}

function Convert-SecureToPlainText {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$SecureValue
    )

    $Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)

    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
    }
}

function Get-ProcessEnvBase64Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $Encoded = [Environment]::GetEnvironmentVariable(
        $Name,
        [EnvironmentVariableTarget]::Process
    )

    if ([string]::IsNullOrWhiteSpace($Encoded)) {
        return $null
    }

    try {
        $Bytes = [Convert]::FromBase64String($Encoded)
        return [System.Text.Encoding]::UTF8.GetString($Bytes)
    }
    catch {
        Stop-Deploy ("Invalid Base64 value in environment variable " + $Name + ".")
    }
}

function Clear-AutomationEnvironment {
    $Names = @(
        "EDU_DEPLOY_MODE",
        "EDU_NEWG_USERNAME_B64",
        "EDU_NEWG_PASSWORD_B64",
        "EDU_GAIA_USERNAME_B64",
        "EDU_GAIA_PASSWORD_B64"
    )

    foreach ($Name in $Names) {
        [Environment]::SetEnvironmentVariable(
            $Name,
            $null,
            [EnvironmentVariableTarget]::Process
        )
    }
}

function Start-InstallNotice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MessageBase64
    )

    $Helper = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

`$Message = [System.Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String("$MessageBase64")
)

`$Form = New-Object System.Windows.Forms.Form
`$Form.Text = "Software Installation"
`$Form.StartPosition = "CenterScreen"
`$Form.Width = 1100
`$Form.Height = 360
`$Form.TopMost = `$true
`$Form.ControlBox = `$false
`$Form.MaximizeBox = `$false
`$Form.MinimizeBox = `$false
`$Form.ShowInTaskbar = `$true

`$Label = New-Object System.Windows.Forms.Label
`$Label.Dock = "Fill"
`$Label.TextAlign = "MiddleCenter"
`$Label.Font = New-Object System.Drawing.Font -ArgumentList @(
    "Segoe UI",
    25,
    [System.Drawing.FontStyle]::Bold
)
`$Label.Text = `$Message

`$Form.Controls.Add(`$Label)
[void]`$Form.ShowDialog()
"@

    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Helper)
    $Encoded = [Convert]::ToBase64String($Bytes)

    return Start-Process `
        -FilePath "powershell.exe" `
        -WindowStyle Hidden `
        -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-STA",
            "-EncodedCommand",
            $Encoded
        ) `
        -PassThru
}

function Stop-InstallNotice {
    param(
        $Process
    )

    if ($null -ne $Process) {
        try {
            if (-not $Process.HasExited) {
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
                $Process.WaitForExit(3000) | Out-Null
            }
        }
        catch {
        }
    }
}

function Show-ResultDialog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$IntroBase64,

        [Parameter(Mandatory = $true)]
        [string]$Details
    )

    $Intro = [System.Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String($IntroBase64)
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

        $Form = New-Object System.Windows.Forms.Form
        $Form.Text = $Title
        $Form.StartPosition = "CenterScreen"
        $Form.Width = 900
        $Form.Height = 650
        $Form.TopMost = $true
        $Form.MaximizeBox = $false
        $Form.MinimizeBox = $false
        $Form.ShowInTaskbar = $true

        $Text = New-Object System.Windows.Forms.RichTextBox
        $Text.ReadOnly = $true
        $Text.BorderStyle = "None"
        $Text.Dock = "Fill"
        $Text.Font = New-Object System.Drawing.Font -ArgumentList @(
            "Segoe UI",
            16,
            [System.Drawing.FontStyle]::Regular
        )
        $Text.Text = $Intro + [Environment]::NewLine + [Environment]::NewLine + $Details
        $Text.BackColor = [System.Drawing.SystemColors]::Window

        $Panel = New-Object System.Windows.Forms.Panel
        $Panel.Dock = "Bottom"
        $Panel.Height = 70

        $Button = New-Object System.Windows.Forms.Button
        $Button.Text = "OK"
        $Button.Width = 140
        $Button.Height = 42
        $Button.Left = 360
        $Button.Top = 12
        $Button.Add_Click({ $Form.Close() })

        $Panel.Controls.Add($Button)
        $Form.Controls.Add($Text)
        $Form.Controls.Add($Panel)

        $Form.Add_Shown({
            $Form.Activate()
            $Button.Focus()
        })

        [void]$Form.ShowDialog()
        $Form.Dispose()
    }
    catch {
        try {
            [void][System.Windows.Forms.MessageBox]::Show(
                $Intro + [Environment]::NewLine + [Environment]::NewLine + $Details,
                $Title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        catch {
            Write-Host ""
            Write-Host $Title -ForegroundColor Cyan
            Write-Host $Intro
            Write-Host $Details
            Write-Host ""
        }
    }
}
function Test-DirectoryWritable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
        }

        $Probe = Join-Path $Path (".write-test-" + [guid]::NewGuid().ToString("N") + ".tmp")
        [System.IO.File]::WriteAllText($Probe, "test")
        Remove-Item -LiteralPath $Probe -Force -ErrorAction Stop

        return $true
    }
    catch {
        return $false
    }
}

function Get-FreeBytes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $Root = [System.IO.Path]::GetPathRoot($FullPath)
    $Drive = New-Object System.IO.DriveInfo -ArgumentList $Root

    return [int64]$Drive.AvailableFreeSpace
}

function Resolve-InstallBase {
    param(
        [Parameter(Mandatory = $true)]
        [int64]$RequiredBytes
    )

    # Prefer writable fixed disks other than C: and the Windows system drive.
    # D: is preferred first, then E:, F:, G: and so on. The system/user
    # profile drive is used only when no other fixed disk is suitable.

    $SystemRoot = $null

    try {
        $SystemRoot = [System.IO.Path]::GetPathRoot($env:SystemRoot)
    }
    catch {
    }

    $ExcludedRoots = @("C:\")

    if (-not [string]::IsNullOrWhiteSpace($SystemRoot)) {
        $ExcludedRoots += $SystemRoot
    }

    $ExcludedRoots = @(
        $ExcludedRoots |
        ForEach-Object { $_.ToUpperInvariant() } |
        Select-Object -Unique
    )

    $PreferredDrives = @()

    try {
        $PreferredDrives = @(
            [System.IO.DriveInfo]::GetDrives() |
            Where-Object {
                $_.DriveType -eq [System.IO.DriveType]::Fixed -and
                $_.IsReady -and
                ($ExcludedRoots -notcontains $_.RootDirectory.FullName.ToUpperInvariant())
            } |
            Sort-Object @{
                Expression = {
                    if ($_.Name.ToUpperInvariant() -eq "D:\") { 0 } else { 1 }
                }
            }, @{
                Expression = { $_.Name }
            }
        )
    }
    catch {
        $PreferredDrives = @()
    }

    foreach ($Drive in $PreferredDrives) {
        $Root = $Drive.RootDirectory.FullName
        $Free = [int64]$Drive.AvailableFreeSpace

        Write-Host (
            "[DRIVE] Checking " + $Root +
            " free=" + [Math]::Round($Free / 1GB, 2) + " GB"
        )

        if ($Free -lt $RequiredBytes) {
            Write-Host (
                "[DRIVE] Skipping " + $Root +
                " because free space is insufficient."
            ) -ForegroundColor Yellow
            continue
        }

        if (-not (Test-DirectoryWritable -Path $Root)) {
            Write-Host (
                "[DRIVE] Skipping " + $Root +
                " because it is not writable."
            ) -ForegroundColor Yellow
            continue
        }

        Write-Host (
            "[DRIVE] Selected preferred install drive: " + $Root
        ) -ForegroundColor Green

        return $Root
    }

    $LocalBase = $env:LOCALAPPDATA

    if ([string]::IsNullOrWhiteSpace($LocalBase)) {
        Stop-Deploy "LOCALAPPDATA is not available."
    }

    Write-Host (
        "[DRIVE] No suitable non-system fixed disk was found. " +
        "Falling back to LOCALAPPDATA: " + $LocalBase
    ) -ForegroundColor Yellow

    if (-not (Test-DirectoryWritable -Path $LocalBase)) {
        Stop-Deploy "No writable installation location is available."
    }

    $LocalFree = Get-FreeBytes -Path $LocalBase

    if ($LocalFree -lt $RequiredBytes) {
        Stop-Deploy "Not enough free disk space on the fallback system drive."
    }

    return $LocalBase
}

function Get-LatestPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageType
    )

    $Query = "'$DriveFolderId' in parents and trashed = false"
    $EncodedQuery = [System.Uri]::EscapeDataString($Query)
    $Fields = "files(id,name,mimeType,size,modifiedTime)"
    $EncodedFields = [System.Uri]::EscapeDataString($Fields)
    $EncodedKey = [System.Uri]::EscapeDataString($ApiKey)

    $Url =
        "https://www.googleapis.com/drive/v3/files" +
        "?q=$EncodedQuery" +
        "&pageSize=1000" +
        "&supportsAllDrives=true" +
        "&includeItemsFromAllDrives=true" +
        "&fields=$EncodedFields" +
        "&key=$EncodedKey"

    try {
        $Response = Invoke-RestMethod `
            -Uri $Url `
            -Method Get `
            -Headers @{ Accept = "application/json" }
    }
    catch {
        Stop-Deploy ("Google Drive API request failed: " + $_.Exception.Message)
    }

    if (-not $Response.files) {
        Stop-Deploy "No files were returned by Google Drive."
    }

    switch ($PackageType) {
        "NEWG" {
            $Pattern = '^NEWG\s+([0-9]+(?:\.[0-9]+){1,3})\.zip$'
        }

        "GAIA" {
            $Pattern = '^GAIA\s+([0-9]+(?:\.[0-9]+){1,3})\.zip$'
        }

        "COMBINED" {
            $Pattern = '^NEWG\s+gaia\s+([0-9]+(?:\.[0-9]+){1,3})\.zip$'
        }

        default {
            Stop-Deploy "Unknown package type."
        }
    }

    $Candidates = @()

    foreach ($File in $Response.files) {
        if ($File.name -match $Pattern) {
            try {
                $Candidates += [PSCustomObject]@{
                    Name         = $File.name
                    Id           = $File.id
                    Version      = [version]$Matches[1]
                    Size         = [int64]$File.size
                    ModifiedTime = [datetime]$File.modifiedTime
                }
            }
            catch {
            }
        }
    }

    if ($Candidates.Count -eq 0) {
        Stop-Deploy ("No matching package was found for " + $PackageType + ".")
    }

    return (
        $Candidates |
        Sort-Object `
            @{ Expression = { $_.Version }; Descending = $true },
            @{ Expression = { $_.ModifiedTime }; Descending = $true } |
        Select-Object -First 1
    )
}

function Test-ZipFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $Stream = $null

    try {
        $Stream = [System.IO.File]::OpenRead($Path)

        if ($Stream.Length -lt 4) {
            return $false
        }

        $Header = New-Object byte[] 4
        [void]$Stream.Read($Header, 0, 4)

        if (
            $Header[0] -eq 0x50 -and
            $Header[1] -eq 0x4B -and
            (
                ($Header[2] -eq 0x03 -and $Header[3] -eq 0x04) -or
                ($Header[2] -eq 0x05 -and $Header[3] -eq 0x06) -or
                ($Header[2] -eq 0x07 -and $Header[3] -eq 0x08)
            )
        ) {
            return $true
        }

        return $false
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $Stream) {
            $Stream.Dispose()
        }
    }
}

function Download-GoogleDriveFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileId,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [int64]$ExpectedSize
    )

    if (
        (Test-Path -LiteralPath $Destination) -and
        ((Get-Item -LiteralPath $Destination).Length -eq $ExpectedSize) -and
        (Test-ZipFile -Path $Destination)
    ) {
        return
    }

    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        Stop-Deploy "curl.exe was not found."
    }

    $Directory = [System.IO.Path]::GetDirectoryName($Destination)
    $PartFile = $Destination + ".part"
    $TempHtml = Join-Path $Directory ("gdrive-" + [guid]::NewGuid().ToString("N") + ".tmp")
    $CookieFile = Join-Path $Directory ("gdrive-" + [guid]::NewGuid().ToString("N") + ".cookie")

    Remove-Item -LiteralPath $PartFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $TempHtml -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $CookieFile -Force -ErrorAction SilentlyContinue

    try {
        $InitialUrl = "https://drive.google.com/uc?export=download&id=$FileId"

        & curl.exe `
            --location `
            --fail `
            --silent `
            --show-error `
            --cookie-jar "$CookieFile" `
            --output "$TempHtml" `
            "$InitialUrl"

        if ($LASTEXITCODE -ne 0) {
            Stop-Deploy "Initial Google Drive download request failed."
        }

        if (Test-ZipFile -Path $TempHtml) {
            Move-Item -LiteralPath $TempHtml -Destination $PartFile -Force
        }
        else {
            $Html = Get-Content -LiteralPath $TempHtml -Raw

            $FormMatch = [regex]::Match(
                $Html,
                '<form\b[^>]*action="([^"]+)"[^>]*>',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )

            if (-not $FormMatch.Success) {
                Stop-Deploy "Google Drive confirmation form was not found."
            }

            $Action = [System.Net.WebUtility]::HtmlDecode(
                $FormMatch.Groups[1].Value
            )

            $InputTags = [regex]::Matches(
                $Html,
                '<input\b[^>]*>',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )

            $Parameters = @()

            foreach ($InputTag in $InputTags) {
                $Tag = $InputTag.Value

                $NameMatch = [regex]::Match(
                    $Tag,
                    'name="([^"]+)"',
                    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                )

                if (-not $NameMatch.Success) {
                    continue
                }

                $ValueMatch = [regex]::Match(
                    $Tag,
                    'value="([^"]*)"',
                    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                )

                $Name = [System.Net.WebUtility]::HtmlDecode(
                    $NameMatch.Groups[1].Value
                )

                $Value = ""

                if ($ValueMatch.Success) {
                    $Value = [System.Net.WebUtility]::HtmlDecode(
                        $ValueMatch.Groups[1].Value
                    )
                }

                $Parameters += (
                    [System.Uri]::EscapeDataString($Name) +
                    "=" +
                    [System.Uri]::EscapeDataString($Value)
                )
            }

            if ($Parameters.Count -eq 0) {
                Stop-Deploy "Google Drive confirmation parameters were not found."
            }

            if ($Action.Contains("?")) {
                $DirectUrl = $Action + "&" + ($Parameters -join "&")
            }
            else {
                $DirectUrl = $Action + "?" + ($Parameters -join "&")
            }

            & curl.exe `
                --location `
                --fail `
                --show-error `
                --progress-bar `
                --cookie "$CookieFile" `
                --output "$PartFile" `
                "$DirectUrl"

            if ($LASTEXITCODE -ne 0) {
                Stop-Deploy "Google Drive file download failed."
            }
        }

        if (-not (Test-Path -LiteralPath $PartFile)) {
            Stop-Deploy "Downloaded package file was not created."
        }

        $ActualSize = [int64](Get-Item -LiteralPath $PartFile).Length

        if ($ActualSize -ne $ExpectedSize) {
            Stop-Deploy (
                "Downloaded package size mismatch. Expected " +
                $ExpectedSize +
                " bytes, received " +
                $ActualSize +
                " bytes."
            )
        }

        if (-not (Test-ZipFile -Path $PartFile)) {
            Stop-Deploy "Downloaded package is not a valid ZIP file."
        }

        Move-Item -LiteralPath $PartFile -Destination $Destination -Force
    }
    finally {
        Remove-Item -LiteralPath $TempHtml -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $CookieFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $PartFile -Force -ErrorAction SilentlyContinue
    }
}

function Extract-AppFromZip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet("NEWG", "GAIA")]
        [string]$AppType,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $Archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

    try {
        if ($AppType -eq "NEWG") {
            $MainName = "NewG.exe"
        }
        else {
            $MainName = "GaiaClient.exe"
        }

        $MainEntries = @(
            $Archive.Entries |
            Where-Object {
                $_.Name -ieq $MainName -and
                $_.FullName -notmatch '(?i)/app\.publish/'
            }
        )

        if ($MainEntries.Count -eq 0) {
            Stop-Deploy ("Main executable " + $MainName + " was not found inside the ZIP.")
        }

        $MainEntry = $MainEntries |
            Sort-Object { $_.FullName.Length } |
            Select-Object -First 1

        $Prefix = $MainEntry.FullName.Substring(
            0,
            $MainEntry.FullName.Length - $MainEntry.Name.Length
        )

        New-Item -ItemType Directory -Path $Destination -Force | Out-Null

        $DestinationRoot = [System.IO.Path]::GetFullPath($Destination)

        if (-not $DestinationRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $DestinationRoot += [System.IO.Path]::DirectorySeparatorChar
        }

        foreach ($Entry in $Archive.Entries) {
            if (-not $Entry.FullName.StartsWith(
                $Prefix,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
                continue
            }

            $Relative = $Entry.FullName.Substring($Prefix.Length)

            if ([string]::IsNullOrWhiteSpace($Relative)) {
                continue
            }

            $Relative = $Relative.Replace(
                '/',
                [System.IO.Path]::DirectorySeparatorChar
            )

            $TargetPath = [System.IO.Path]::GetFullPath(
                (Join-Path $Destination $Relative)
            )

            if (-not $TargetPath.StartsWith(
                $DestinationRoot,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
                Stop-Deploy "Unsafe path was detected inside the ZIP package."
            }

            if ([string]::IsNullOrEmpty($Entry.Name)) {
                New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
                continue
            }

            $TargetDirectory = [System.IO.Path]::GetDirectoryName($TargetPath)

            if (-not (Test-Path -LiteralPath $TargetDirectory)) {
                New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
            }

            $InputStream = $null
            $OutputStream = $null

            try {
                $InputStream = $Entry.Open()

                $OutputStream = [System.IO.File]::Open(
                    $TargetPath,
                    [System.IO.FileMode]::Create,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None
                )

                $InputStream.CopyTo($OutputStream)
            }
            finally {
                if ($null -ne $OutputStream) {
                    $OutputStream.Dispose()
                }

                if ($null -ne $InputStream) {
                    $InputStream.Dispose()
                }
            }

            try {
                [System.IO.File]::SetLastWriteTime(
                    $TargetPath,
                    $Entry.LastWriteTime.LocalDateTime
                )
            }
            catch {
            }
        }

        $ExpectedExe = Join-Path $Destination $MainName

        if (-not (Test-Path -LiteralPath $ExpectedExe)) {
            Stop-Deploy ("Extraction completed but " + $MainName + " is missing.")
        }

        return $ExpectedExe
    }
    finally {
        $Archive.Dispose()
    }
}

function Get-VCRuntimeX86 {
    $Paths = @(
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86"
    )

    foreach ($Path in $Paths) {
        if (Test-Path -LiteralPath $Path) {
            $Runtime = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue

            if ($Runtime.Installed -eq 1) {
                return $Runtime
            }
        }
    }

    return $null
}

function Ensure-VCRuntimeX86 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CacheRoot
    )

    $Existing = Get-VCRuntimeX86

    if ($null -ne $Existing) {
        return [PSCustomObject]@{
            InstalledNow = $false
            Version      = $Existing.Version
        }
    }

    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        Stop-Deploy "curl.exe was not found for Visual C++ runtime download."
    }

    $Installer = Join-Path $CacheRoot "vc_redist.x86.exe"
    $VcUrl = "https://aka.ms/vc14/vc_redist.x86.exe"

    & curl.exe `
        --location `
        --fail `
        --show-error `
        --progress-bar `
        --output "$Installer" `
        "$VcUrl"

    if ($LASTEXITCODE -ne 0) {
        Stop-Deploy "Visual C++ x86 runtime download failed."
    }

    if (
        -not (Test-Path -LiteralPath $Installer) -or
        (Get-Item -LiteralPath $Installer).Length -lt 1MB
    ) {
        Stop-Deploy "Visual C++ x86 runtime installer is invalid."
    }

    try {
        $InstallProcess = Start-Process `
            -FilePath $Installer `
            -ArgumentList @(
                "/install",
                "/quiet",
                "/norestart"
            ) `
            -Verb RunAs `
            -Wait `
            -PassThru
    }
    catch {
        Stop-Deploy (
            "Visual C++ x86 runtime installation could not start: " +
            $_.Exception.Message
        )
    }

    if ($InstallProcess.ExitCode -notin @(0, 1638, 3010)) {
        Stop-Deploy (
            "Visual C++ x86 runtime installer returned exit code " +
            $InstallProcess.ExitCode +
            "."
        )
    }

    Start-Sleep -Seconds 2

    $Installed = Get-VCRuntimeX86

    if ($null -eq $Installed) {
        Stop-Deploy "Visual C++ x86 runtime is still not detected after installation."
    }

    return [PSCustomObject]@{
        InstalledNow = $true
        Version      = $Installed.Version
    }
}

function Get-DesktopCandidates {
    $RawCandidates = @()

    # Registry is the authoritative per-user known-folder location.
    try {
        $UserShellFolders = Get-ItemProperty `
            -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" `
            -ErrorAction Stop

        if ($UserShellFolders.Desktop) {
            $RawCandidates += [string]$UserShellFolders.Desktop
        }
    }
    catch {
    }

    # Physical desktop directory returned by .NET.
    try {
        $RawCandidates += [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::DesktopDirectory
        )
    }
    catch {
    }

    # WScript known folder. This can point to OneDrive on redirected systems.
    try {
        $Shell = New-Object -ComObject WScript.Shell
        $RawCandidates += [string]$Shell.SpecialFolders.Item("Desktop")
    }
    catch {
    }

    # Local profile fallback. This is intentionally included even when
    # OneDrive desktop redirection is broken or unavailable.
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $RawCandidates += (Join-Path $env:USERPROFILE "Desktop")
    }

    # Common English OneDrive layout, when present.
    if (-not [string]::IsNullOrWhiteSpace($env:OneDrive)) {
        $RawCandidates += (Join-Path $env:OneDrive "Desktop")
    }

    # Public desktop is only used if the current user can write to it.
    try {
        $RawCandidates += [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::CommonDesktopDirectory
        )
    }
    catch {
    }

    $Candidates = @()

    foreach ($RawPath in $RawCandidates) {
        if ([string]::IsNullOrWhiteSpace($RawPath)) {
            continue
        }

        try {
            $Candidate = [Environment]::ExpandEnvironmentVariables(
                $RawPath.Trim().Trim([char]34)
            )

            if ([string]::IsNullOrWhiteSpace($Candidate)) {
                continue
            }

            $Candidate = [System.IO.Path]::GetFullPath($Candidate)

            if ($Candidates -notcontains $Candidate) {
                $Candidates += $Candidate
            }
        }
        catch {
        }
    }

    return $Candidates
}

function New-DesktopShortcut {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ShortcutName,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        Stop-Deploy ("Shortcut target does not exist: " + $TargetPath)
    }

    $Candidates = @(Get-DesktopCandidates)

    # Ensure the normal local Desktop exists as a last-resort user-writable
    # location. Do not create missing OneDrive/redirection paths automatically.
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $LocalDesktop = Join-Path $env:USERPROFILE "Desktop"

        try {
            if (-not (Test-Path -LiteralPath $LocalDesktop -PathType Container)) {
                New-Item `
                    -ItemType Directory `
                    -Path $LocalDesktop `
                    -Force `
                    -ErrorAction Stop | Out-Null
            }

            $LocalDesktop = [System.IO.Path]::GetFullPath($LocalDesktop)

            if ($Candidates -notcontains $LocalDesktop) {
                $Candidates += $LocalDesktop
            }
        }
        catch {
        }
    }

    if ($Candidates.Count -eq 0) {
        Stop-Deploy "No Desktop folder candidate could be resolved."
    }

    $Shell = New-Object -ComObject WScript.Shell
    $Tried = @()

    foreach ($Desktop in $Candidates) {
        $Tried += $Desktop

        # Never create a missing redirected path here. Broken OneDrive known
        # folders are skipped and the function falls back to another Desktop.
        if (-not (Test-Path -LiteralPath $Desktop -PathType Container)) {
            Write-Host ("[SHORTCUT] Skipping missing Desktop: " + $Desktop) -ForegroundColor Yellow
            continue
        }

        if (-not (Test-DirectoryWritable -Path $Desktop)) {
            Write-Host ("[SHORTCUT] Desktop is not writable: " + $Desktop) -ForegroundColor Yellow
            continue
        }

        $ShortcutPath = Join-Path $Desktop ($ShortcutName + ".lnk")

        try {
            Write-Host ("[SHORTCUT] Trying: " + $ShortcutPath)

            Remove-Item `
                -LiteralPath $ShortcutPath `
                -Force `
                -ErrorAction SilentlyContinue

            $Shortcut = $Shell.CreateShortcut($ShortcutPath)
            $Shortcut.TargetPath = $TargetPath
            $Shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($TargetPath)
            $Shortcut.IconLocation = $TargetPath + ",0"
            $Shortcut.Save()

            if (Test-Path -LiteralPath $ShortcutPath -PathType Leaf) {
                Write-Host ("[SHORTCUT] Created: " + $ShortcutPath) -ForegroundColor Green
                return $ShortcutPath
            }
        }
        catch {
            Write-Host ("[SHORTCUT] Failed at Desktop: " + $Desktop) -ForegroundColor Yellow
            Write-Host ("[SHORTCUT] Reason: " + $_.Exception.Message) -ForegroundColor DarkYellow
        }
    }

    Stop-Deploy (
        "Unable to create desktop shortcut '" +
        $ShortcutName +
        "'. Tried: " +
        ($Tried -join " | ")
    )
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if ($null -eq ("EduDeployNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class EduDeployNative
{
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(
        IntPtr hWnd
    );

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(
        IntPtr hWnd,
        int nCmdShow
    );

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags
    );

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(
        IntPtr hWnd,
        out RECT lpRect
    );

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(
        IntPtr hWnd,
        out RECT lpRect
    );

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(
        IntPtr hWnd,
        ref POINT lpPoint
    );

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(
        out POINT lpPoint
    );

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(
        int X,
        int Y
    );

    [DllImport("user32.dll")]
    public static extern bool ClipCursor(
        ref RECT lpRect
    );

    [DllImport(
        "user32.dll",
        EntryPoint = "ClipCursor"
    )]
    public static extern bool ReleaseClipCursor(
        IntPtr lpRect
    );

    [DllImport("user32.dll")]
    public static extern void mouse_event(
        uint dwFlags,
        uint dx,
        uint dy,
        uint dwData,
        UIntPtr dwExtraInfo
    );

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    public static readonly IntPtr HWND_TOPMOST =
        new IntPtr(-1);

    public static readonly IntPtr HWND_NOTOPMOST =
        new IntPtr(-2);

    public const int SW_RESTORE  = 9;
    public const int SW_MINIMIZE = 6;

    public const uint SWP_NOSIZE     = 0x0001;
    public const uint SWP_NOMOVE     = 0x0002;
    public const uint SWP_SHOWWINDOW = 0x0040;

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP   = 0x0004;

    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public struct POINT
    {
        public int X;
        public int Y;
    }
}
"@
}

function Set-AppFocus {
    param(
        [Parameter(Mandatory = $true)]
        [IntPtr]$Handle,

        [Parameter(Mandatory = $true)]
        [int]$ProcessId
    )

    [EduDeployNative]::ShowWindow(
        $Handle,
        [EduDeployNative]::SW_RESTORE
    ) | Out-Null

    [EduDeployNative]::SetWindowPos(
        $Handle,
        [EduDeployNative]::HWND_TOPMOST,
        0,
        0,
        0,
        0,
        (
            [EduDeployNative]::SWP_NOMOVE -bor
            [EduDeployNative]::SWP_NOSIZE -bor
            [EduDeployNative]::SWP_SHOWWINDOW
        )
    ) | Out-Null

    [EduDeployNative]::SetForegroundWindow($Handle) | Out-Null

    try {
        $Shell = New-Object -ComObject WScript.Shell
        [void]$Shell.AppActivate($ProcessId)
    }
    catch {
    }

    Start-Sleep -Milliseconds 200
}

function Set-AppStandardWindow {
    param(
        [Parameter(Mandatory = $true)]
        [IntPtr]$Handle
    )

    [EduDeployNative]::ShowWindow(
        $Handle,
        [EduDeployNative]::SW_RESTORE
    ) | Out-Null

    Start-Sleep -Milliseconds 300

    $WindowRect = New-Object EduDeployNative+RECT
    $ClientRect = New-Object EduDeployNative+RECT

    [EduDeployNative]::GetWindowRect(
        $Handle,
        [ref]$WindowRect
    ) | Out-Null

    [EduDeployNative]::GetClientRect(
        $Handle,
        [ref]$ClientRect
    ) | Out-Null

    $OuterWidth = $WindowRect.Right - $WindowRect.Left
    $OuterHeight = $WindowRect.Bottom - $WindowRect.Top
    $CurrentClientWidth = $ClientRect.Right - $ClientRect.Left
    $CurrentClientHeight = $ClientRect.Bottom - $ClientRect.Top

    $BorderWidth = $OuterWidth - $CurrentClientWidth
    $BorderHeight = $OuterHeight - $CurrentClientHeight

    $TargetOuterWidth = $TargetClientWidth + $BorderWidth
    $TargetOuterHeight = $TargetClientHeight + $BorderHeight

    $Screen = [System.Windows.Forms.Screen]::FromHandle($Handle)
    $WorkingArea = $Screen.WorkingArea

    if (
        $TargetOuterWidth -gt $WorkingArea.Width -or
        $TargetOuterHeight -gt $WorkingArea.Height
    ) {
        $ScaleX = ($WorkingArea.Width - 20) / [double]$TargetOuterWidth
        $ScaleY = ($WorkingArea.Height - 20) / [double]$TargetOuterHeight
        $Scale = [Math]::Min($ScaleX, $ScaleY)

        if ($Scale -le 0) {
            Stop-Deploy "The display working area is too small for application automation."
        }

        $TargetOuterWidth = [int]($TargetOuterWidth * $Scale)
        $TargetOuterHeight = [int]($TargetOuterHeight * $Scale)
    }

    $X = [int](
        $WorkingArea.Left +
        (($WorkingArea.Width - $TargetOuterWidth) / 2)
    )

    $Y = [int](
        $WorkingArea.Top +
        (($WorkingArea.Height - $TargetOuterHeight) / 2)
    )

    [EduDeployNative]::SetWindowPos(
        $Handle,
        [IntPtr]::Zero,
        $X,
        $Y,
        $TargetOuterWidth,
        $TargetOuterHeight,
        [EduDeployNative]::SWP_SHOWWINDOW
    ) | Out-Null

    Start-Sleep -Milliseconds 800

    $FinalClientRect = New-Object EduDeployNative+RECT

    [EduDeployNative]::GetClientRect(
        $Handle,
        [ref]$FinalClientRect
    ) | Out-Null

    $Origin = New-Object EduDeployNative+POINT
    $Origin.X = 0
    $Origin.Y = 0

    [EduDeployNative]::ClientToScreen(
        $Handle,
        [ref]$Origin
    ) | Out-Null

    return [PSCustomObject]@{
        OriginX = $Origin.X
        OriginY = $Origin.Y
        Width   = $FinalClientRect.Right - $FinalClientRect.Left
        Height  = $FinalClientRect.Bottom - $FinalClientRect.Top
    }
}

function Get-AppClientGeometry {
    param(
        [Parameter(Mandatory = $true)]
        [IntPtr]$Handle
    )

    $ClientRect = New-Object EduDeployNative+RECT

    if (-not [EduDeployNative]::GetClientRect(
        $Handle,
        [ref]$ClientRect
    )) {
        Stop-Deploy "Unable to read application client geometry."
    }

    $Origin = New-Object EduDeployNative+POINT
    $Origin.X = 0
    $Origin.Y = 0

    if (-not [EduDeployNative]::ClientToScreen(
        $Handle,
        [ref]$Origin
    )) {
        Stop-Deploy "Unable to resolve application client origin."
    }

    $Width = $ClientRect.Right - $ClientRect.Left
    $Height = $ClientRect.Bottom - $ClientRect.Top

    if ($Width -lt 300 -or $Height -lt 300) {
        Stop-Deploy "Application client area is not ready."
    }

    return [PSCustomObject]@{
        OriginX = $Origin.X
        OriginY = $Origin.Y
        Width   = $Width
        Height  = $Height
    }
}

function Invoke-AppClick {
    param(
        [Parameter(Mandatory = $true)]
        [IntPtr]$Handle,

        [Parameter(Mandatory = $true)]
        [int]$ProcessId,

        [Parameter(Mandatory = $true)]
        $Geometry,

        [Parameter(Mandatory = $true)]
        [double]$XRatio,

        [Parameter(Mandatory = $true)]
        [double]$YRatio
    )

    Set-AppFocus -Handle $Handle -ProcessId $ProcessId

    $ScreenX = $Geometry.OriginX + [int]($Geometry.Width * $XRatio)
    $ScreenY = $Geometry.OriginY + [int]($Geometry.Height * $YRatio)

    $LockRect = New-Object EduDeployNative+RECT
    $LockRect.Left   = $ScreenX
    $LockRect.Top    = $ScreenY
    $LockRect.Right  = $ScreenX + 2
    $LockRect.Bottom = $ScreenY + 2

    [EduDeployNative]::ClipCursor(
        [ref]$LockRect
    ) | Out-Null

    [EduDeployNative]::SetCursorPos(
        $ScreenX,
        $ScreenY
    ) | Out-Null

    Start-Sleep -Milliseconds 100

    [EduDeployNative]::mouse_event(
        [EduDeployNative]::MOUSEEVENTF_LEFTDOWN,
        0,
        0,
        0,
        [UIntPtr]::Zero
    )

    Start-Sleep -Milliseconds 70

    [EduDeployNative]::mouse_event(
        [EduDeployNative]::MOUSEEVENTF_LEFTUP,
        0,
        0,
        0,
        [UIntPtr]::Zero
    )

    Start-Sleep -Milliseconds 200
}

function Get-AppSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        $Geometry
    )

    $Bitmap = New-Object System.Drawing.Bitmap -ArgumentList @(
        $Geometry.Width,
        $Geometry.Height
    )

    $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)

    try {
        $Graphics.CopyFromScreen(
            $Geometry.OriginX,
            $Geometry.OriginY,
            0,
            0,
            $Bitmap.Size,
            [System.Drawing.CopyPixelOperation]::SourceCopy
        )
    }
    finally {
        $Graphics.Dispose()
    }

    return $Bitmap
}

function Get-LoginScreenSignature {
    param(
        [Parameter(Mandatory = $true)]
        $Geometry
    )

    $Bitmap = Get-AppSnapshot -Geometry $Geometry

    try {
        # Search a broad lower-right area instead of one exact button box.
        # This tolerates DPI scaling, responsive HTML layout and small
        # differences in the normalized client size.
        $OrangeLeft   = [int]($Bitmap.Width * 0.45)
        $OrangeTop    = [int]($Bitmap.Height * 0.62)
        $OrangeRight  = [int]($Bitmap.Width * 0.90)
        $OrangeBottom = [int]($Bitmap.Height * 0.94)

        # The login form itself contains a large light/white panel.
        $LightLeft   = [int]($Bitmap.Width * 0.18)
        $LightTop    = [int]($Bitmap.Height * 0.24)
        $LightRight  = [int]($Bitmap.Width * 0.82)
        $LightBottom = [int]($Bitmap.Height * 0.77)

        # The technical-support button is a large dark-blue block to the
        # lower-left of the login button. It is used as a second signal in
        # case GPU/color rendering changes the exact orange tone.
        $BlueLeft   = [int]($Bitmap.Width * 0.18)
        $BlueTop    = [int]($Bitmap.Height * 0.62)
        $BlueRight  = [int]($Bitmap.Width * 0.64)
        $BlueBottom = [int]($Bitmap.Height * 0.94)

        $OrangeCount = 0
        $OrangeTotal = 0

        for (
            $Y = $OrangeTop;
            $Y -lt $OrangeBottom;
            $Y += $LoginReadySampleStep
        ) {
            for (
                $X = $OrangeLeft;
                $X -lt $OrangeRight;
                $X += $LoginReadySampleStep
            ) {
                $Pixel = $Bitmap.GetPixel($X, $Y)
                $R = [int]$Pixel.R
                $G = [int]$Pixel.G
                $B = [int]$Pixel.B

                # Broad orange classifier. The real button is approximately
                # RGB 255,128,15, but the limits intentionally allow GPU,
                # antialiasing and color-profile variation.
                if (
                    $R -ge 170 -and
                    $G -ge 45 -and
                    $G -le 210 -and
                    $B -le 150 -and
                    ($R - $G) -ge 25 -and
                    ($G - $B) -ge 10
                ) {
                    $OrangeCount++
                }

                $OrangeTotal++
            }
        }

        $LightCount = 0
        $LightTotal = 0

        for (
            $Y = $LightTop;
            $Y -lt $LightBottom;
            $Y += $LoginReadySampleStep
        ) {
            for (
                $X = $LightLeft;
                $X -lt $LightRight;
                $X += $LoginReadySampleStep
            ) {
                $Pixel = $Bitmap.GetPixel($X, $Y)
                $R = [int]$Pixel.R
                $G = [int]$Pixel.G
                $B = [int]$Pixel.B

                $MaxChannel = [Math]::Max($R, [Math]::Max($G, $B))
                $MinChannel = [Math]::Min($R, [Math]::Min($G, $B))

                if (
                    $R -ge 210 -and
                    $G -ge 210 -and
                    $B -ge 210 -and
                    ($MaxChannel - $MinChannel) -le 55
                ) {
                    $LightCount++
                }

                $LightTotal++
            }
        }

        $BlueCount = 0
        $BlueTotal = 0

        for (
            $Y = $BlueTop;
            $Y -lt $BlueBottom;
            $Y += $LoginReadySampleStep
        ) {
            for (
                $X = $BlueLeft;
                $X -lt $BlueRight;
                $X += $LoginReadySampleStep
            ) {
                $Pixel = $Bitmap.GetPixel($X, $Y)
                $R = [int]$Pixel.R
                $G = [int]$Pixel.G
                $B = [int]$Pixel.B

                if (
                    $B -ge 100 -and
                    $R -le 140 -and
                    $G -le 190 -and
                    ($B - $R) -ge 45 -and
                    ($B - $G) -ge 10
                ) {
                    $BlueCount++
                }

                $BlueTotal++
            }
        }

        $OrangePercent = 0.0
        $LightPercent = 0.0
        $BluePercent = 0.0

        if ($OrangeTotal -gt 0) {
            $OrangePercent = [Math]::Round(
                ($OrangeCount / [double]$OrangeTotal) * 100,
                2
            )
        }

        if ($LightTotal -gt 0) {
            $LightPercent = [Math]::Round(
                ($LightCount / [double]$LightTotal) * 100,
                2
            )
        }

        if ($BlueTotal -gt 0) {
            $BluePercent = [Math]::Round(
                ($BlueCount / [double]$BlueTotal) * 100,
                2
            )
        }

        return [PSCustomObject]@{
            OrangePercent = $OrangePercent
            LightPercent  = $LightPercent
            BluePercent   = $BluePercent
        }
    }
    finally {
        $Bitmap.Dispose()
    }
}

function Wait-AppLoginReady {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [IntPtr]$Handle,

        [Parameter(Mandatory = $true)]
        [int]$ProcessId
    )

    Write-Host (
        "[READY] Waiting for " + $AppName +
        " login screen..."
    )

    $Deadline = (Get-Date).AddSeconds(
        $LoginReadyTimeoutSeconds
    )

    $ConsecutiveHits = 0
    $Attempt = 0
    $MaxOrange = 0.0
    $MaxLight = 0.0
    $MaxBlue = 0.0
    $ReadyGeometry = $null

    while ((Get-Date) -lt $Deadline) {
        $Attempt++

        $CurrentProcess = Get-Process `
            -Id $ProcessId `
            -ErrorAction SilentlyContinue

        if ($null -eq $CurrentProcess) {
            Stop-Deploy (
                $AppName +
                " exited while waiting for the login screen."
            )
        }

        Set-AppFocus `
            -Handle $Handle `
            -ProcessId $ProcessId

        Start-Sleep -Milliseconds 120

        # Refresh client coordinates every poll. This avoids stale geometry
        # when Windows DPI scaling or the application changes its frame while
        # CefSharp is still starting.
        try {
            $ReadyGeometry = Get-AppClientGeometry -Handle $Handle
        }
        catch {
            $ConsecutiveHits = 0
            Start-Sleep -Milliseconds $LoginReadyPollMs
            continue
        }

        $Signature = Get-LoginScreenSignature `
            -Geometry $ReadyGeometry

        if ($Signature.OrangePercent -gt $MaxOrange) {
            $MaxOrange = $Signature.OrangePercent
        }

        if ($Signature.LightPercent -gt $MaxLight) {
            $MaxLight = $Signature.LightPercent
        }

        if ($Signature.BluePercent -gt $MaxBlue) {
            $MaxBlue = $Signature.BluePercent
        }

        Write-Host (
            "[READY] " + $AppName +
            " orange=" + $Signature.OrangePercent + "%" +
            " light=" + $Signature.LightPercent + "%" +
            " support-blue=" + $Signature.BluePercent + "%"
        )

        $ButtonSignal = (
            $Signature.OrangePercent -ge $LoginReadyOrangeMinPercent -or
            $Signature.BluePercent -ge $LoginReadyBlueMinPercent
        )

        $FormSignal = (
            $Signature.LightPercent -ge $LoginReadyLightMinPercent
        )

        if ($ButtonSignal -and $FormSignal) {
            $ConsecutiveHits++
        }
        else {
            $ConsecutiveHits = 0
        }

        if (
            $ConsecutiveHits -ge
            $LoginReadyRequiredHits
        ) {
            Write-Host (
                "[READY] " + $AppName +
                " login screen detected."
            ) -ForegroundColor Green

            Start-Sleep -Milliseconds $LoginReadyGraceMs

            # Refresh once more after the grace period so subsequent clicks
            # use the current client origin and size.
            $ReadyGeometry = Get-AppClientGeometry -Handle $Handle

            return [PSCustomObject]@{
                Ready         = $true
                MaxOrange     = $MaxOrange
                MaxLight      = $MaxLight
                MaxBlue       = $MaxBlue
                Attempts      = $Attempt
                Geometry      = $ReadyGeometry
            }
        }

        Start-Sleep -Milliseconds $LoginReadyPollMs
    }

    Stop-Deploy (
        $AppName +
        " login screen was not detected within " +
        $LoginReadyTimeoutSeconds +
        " seconds. Max orange=" +
        $MaxOrange + "%, max light=" +
        $MaxLight + "%, max support-blue=" +
        $MaxBlue + "%."
    )
}

function Set-AppFieldValue {
    param(
        [Parameter(Mandatory = $true)]
        [IntPtr]$Handle,

        [Parameter(Mandatory = $true)]
        [int]$ProcessId,

        [Parameter(Mandatory = $true)]
        $Geometry,

        [Parameter(Mandatory = $true)]
        [double]$XRatio,

        [Parameter(Mandatory = $true)]
        [double]$YRatio,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    Invoke-AppClick `
        -Handle $Handle `
        -ProcessId $ProcessId `
        -Geometry $Geometry `
        -XRatio $XRatio `
        -YRatio $YRatio

    Set-AppFocus `
        -Handle $Handle `
        -ProcessId $ProcessId

    Start-Sleep -Milliseconds 120

    [System.Windows.Forms.SendKeys]::SendWait("^a")
    Start-Sleep -Milliseconds 80

    [System.Windows.Forms.Clipboard]::SetText($Value)
    [System.Windows.Forms.SendKeys]::SendWait("^v")

    Start-Sleep -Milliseconds 250
}

function Get-VisualChangePercent {
    param(
        [Parameter(Mandatory = $true)]
        [System.Drawing.Bitmap]$Before,

        [Parameter(Mandatory = $true)]
        [System.Drawing.Bitmap]$After
    )

    $Changed = 0
    $Total = 0

    for ($Y = 0; $Y -lt $Before.Height; $Y += $VisualSampleStep) {
        for ($X = 0; $X -lt $Before.Width; $X += $VisualSampleStep) {
            $PixelA = $Before.GetPixel($X, $Y)
            $PixelB = $After.GetPixel($X, $Y)

            $Difference =
                [Math]::Abs([int]$PixelA.R - [int]$PixelB.R) +
                [Math]::Abs([int]$PixelA.G - [int]$PixelB.G) +
                [Math]::Abs([int]$PixelA.B - [int]$PixelB.B)

            if ($Difference -ge $PixelDifferenceLimit) {
                $Changed++
            }

            $Total++
        }
    }

    if ($Total -eq 0) {
        return 0
    }

    return [Math]::Round(
        ($Changed / [double]$Total) * 100,
        2
    )
}

function Invoke-AppLogin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$ExePath,

        [Parameter(Mandatory = $true)]
        [string]$ProcessName,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $Existing = @(
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    )

    if ($Existing.Count -gt 0) {
        Stop-Deploy (
            $AppName +
            " is already running. Close it before running deployment."
        )
    }

    $LaunchTime = Get-Date

    Start-Process `
        -FilePath $ExePath `
        -WorkingDirectory ([System.IO.Path]::GetDirectoryName($ExePath)) |
        Out-Null

    $WindowProcess = $null
    $Deadline = (Get-Date).AddSeconds(40)

    while (
        ($null -eq $WindowProcess) -and
        ((Get-Date) -lt $Deadline)
    ) {
        Start-Sleep -Milliseconds 500

        $Candidates = @(
            Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        )

        foreach ($Candidate in $Candidates) {
            $Candidate.Refresh()

            if (
                $Candidate.MainWindowHandle -ne 0 -and
                $Candidate.StartTime -ge $LaunchTime.AddSeconds(-3)
            ) {
                $WindowProcess = $Candidate
                break
            }
        }
    }

    if ($null -eq $WindowProcess) {
        Stop-Deploy ($AppName + " did not create a visible window.")
    }

    $Handle = [IntPtr]$WindowProcess.MainWindowHandle

    # A visible HWND can appear before the CefSharp page is rendered.
    # The orange login-button detector below performs the real readiness
    # check, so this is only a very short stabilization delay.
    Start-Sleep -Milliseconds 500

    $Geometry = Set-AppStandardWindow -Handle $Handle

    $OriginalCursor = New-Object EduDeployNative+POINT
    [EduDeployNative]::GetCursorPos([ref]$OriginalCursor) | Out-Null

    $ConsoleHandle = [EduDeployNative]::GetConsoleWindow()
    $Baseline = $null
    $Verified = $false
    $MaxChange = 0.0

    try {
        if ($ConsoleHandle -ne [IntPtr]::Zero) {
            [EduDeployNative]::ShowWindow(
                $ConsoleHandle,
                [EduDeployNative]::SW_MINIMIZE
            ) | Out-Null
        }

        Start-Sleep -Milliseconds 400

        $ReadyResult = Wait-AppLoginReady `
            -AppName $AppName `
            -Handle $Handle `
            -ProcessId $WindowProcess.Id

        $Geometry = $ReadyResult.Geometry

        Write-Host (
            "[INPUT] Entering " + $AppName +
            " username..."
        )

        Set-AppFieldValue `
            -Handle $Handle `
            -ProcessId $WindowProcess.Id `
            -Geometry $Geometry `
            -XRatio $UsernameX `
            -YRatio $UsernameY `
            -Value $Username

        Write-Host (
            "[INPUT] Entering " + $AppName +
            " password..."
        )

        Set-AppFieldValue `
            -Handle $Handle `
            -ProcessId $WindowProcess.Id `
            -Geometry $Geometry `
            -XRatio $PasswordX `
            -YRatio $PasswordY `
            -Value $Password

        Start-Sleep -Milliseconds 500

        Set-AppFocus -Handle $Handle -ProcessId $WindowProcess.Id
        $Baseline = Get-AppSnapshot -Geometry $Geometry

        Invoke-AppClick `
            -Handle $Handle `
            -ProcessId $WindowProcess.Id `
            -Geometry $Geometry `
            -XRatio $LoginX `
            -YRatio $LoginY

        [EduDeployNative]::ReleaseClipCursor(
            [IntPtr]::Zero
        ) | Out-Null

        $VerifyDeadline = (Get-Date).AddSeconds(
            $VisualTimeoutSeconds
        )

        $ConsecutiveHits = 0

        while ((Get-Date) -lt $VerifyDeadline) {
            Start-Sleep -Seconds 1

            $CurrentProcess = Get-Process `
                -Id $WindowProcess.Id `
                -ErrorAction SilentlyContinue

            if ($null -eq $CurrentProcess) {
                break
            }

            $Current = Get-AppSnapshot -Geometry $Geometry

            try {
                $Change = Get-VisualChangePercent `
                    -Before $Baseline `
                    -After $Current

                if ($Change -gt $MaxChange) {
                    $MaxChange = $Change
                }

                Write-Host (
                    "[VERIFY] " + $AppName +
                    " screen change: " + $Change + "%"
                )

                if ($Change -ge $VisualChangeThreshold) {
                    $ConsecutiveHits++
                }
                else {
                    $ConsecutiveHits = 0
                }

                if ($ConsecutiveHits -ge $VisualRequiredHits) {
                    $Verified = $true
                    break
                }
            }
            finally {
                $Current.Dispose()
            }
        }
    }
    finally {
        [EduDeployNative]::ReleaseClipCursor(
            [IntPtr]::Zero
        ) | Out-Null

        [EduDeployNative]::SetCursorPos(
            $OriginalCursor.X,
            $OriginalCursor.Y
        ) | Out-Null

        if ($Handle -ne [IntPtr]::Zero) {
            [EduDeployNative]::SetWindowPos(
                $Handle,
                [EduDeployNative]::HWND_NOTOPMOST,
                0,
                0,
                0,
                0,
                (
                    [EduDeployNative]::SWP_NOMOVE -bor
                    [EduDeployNative]::SWP_NOSIZE
                )
            ) | Out-Null
        }

        if ($ConsoleHandle -ne [IntPtr]::Zero) {
            [EduDeployNative]::ShowWindow(
                $ConsoleHandle,
                [EduDeployNative]::SW_RESTORE
            ) | Out-Null
        }

        if ($null -ne $Baseline) {
            $Baseline.Dispose()
        }
    }

    Write-Host ""
    Write-Host (
        "[LOGIN] " + $AppName +
        " verified=" + $Verified +
        "; maxChange=" + $MaxChange + "%"
    )
    Write-Host ""

    return [PSCustomObject]@{
        Verified  = $Verified
        MaxChange = $MaxChange
        ProcessId = $WindowProcess.Id
    }
}

function Arm-SelfDelete {
    $SelfPath = $PSCommandPath

    if ([string]::IsNullOrWhiteSpace($SelfPath)) {
        Stop-Deploy "Current script path could not be resolved for self-delete."
    }

    $SelfPath = [System.IO.Path]::GetFullPath($SelfPath)
    $EscapedPath = $SelfPath.Replace("'", "''")

    $LauncherPath = Join-Path (
        [System.IO.Path]::GetDirectoryName($SelfPath)
    ) "Deploy-Education.cmd"

    $EscapedLauncherPath = $LauncherPath.Replace("'", "''")
    $ParentPid = $PID

    $CleanupLines = @()
    $CleanupLines += '$ErrorActionPreference = "SilentlyContinue"'
    $CleanupLines += ('$TargetPath = ''' + $EscapedPath + '''')
    $CleanupLines += ('$LauncherPath = ''' + $EscapedLauncherPath + '''')
    $CleanupLines += ('$ParentPid = ' + $ParentPid)
    $CleanupLines += 'for ($i = 0; $i -lt 80; $i++) {'
    $CleanupLines += '    $Parent = Get-Process -Id $ParentPid -ErrorAction SilentlyContinue'
    $CleanupLines += '    if (-not $Parent) { break }'
    $CleanupLines += '    Start-Sleep -Milliseconds 250'
    $CleanupLines += '}'
    $CleanupLines += 'for ($i = 0; $i -lt 20; $i++) {'
    $CleanupLines += '    if (-not (Test-Path -LiteralPath $TargetPath)) { break }'
    $CleanupLines += '    Remove-Item -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue'
    $CleanupLines += '    Start-Sleep -Milliseconds 250'
    $CleanupLines += '}'
    $CleanupLines += 'for ($i = 0; $i -lt 20; $i++) {'
    $CleanupLines += '    if (-not (Test-Path -LiteralPath $LauncherPath)) { break }'
    $CleanupLines += '    Remove-Item -LiteralPath $LauncherPath -Force -ErrorAction SilentlyContinue'
    $CleanupLines += '    Start-Sleep -Milliseconds 250'
    $CleanupLines += '}'

    $CleanupScript = $CleanupLines -join [Environment]::NewLine
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($CleanupScript)
    $Encoded = [Convert]::ToBase64String($Bytes)

    try {
        $Helper = Start-Process `
            -FilePath "powershell.exe" `
            -WindowStyle Hidden `
            -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-EncodedCommand",
                $Encoded
            ) `
            -PassThru
    }
    catch {
        Stop-Deploy (
            "Self-delete helper could not start: " +
            $_.Exception.Message
        )
    }

    if ($null -eq $Helper) {
        Stop-Deploy "Self-delete helper did not start."
    }
}
Clear-Host

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "       EDUCATION SOFTWARE DEPLOYMENT"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

if (
    [string]::IsNullOrWhiteSpace($ApiKey) -or
    $ApiKey -eq "PASTE_YOUR_GOOGLE_DRIVE_API_KEY_HERE"
) {
    Write-Host "[ERROR] Google Drive API key is not configured." -ForegroundColor Red
    Write-Host ""
    Write-Host "Edit this line near the top of the script:"
    Write-Host '$ApiKey = "PASTE_YOUR_GOOGLE_DRIVE_API_KEY_HERE"'
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

$Choice = $null
$NewGUsername = $null
$NewGPassword = $null
$GaiaUsername = $null
$GaiaPassword = $null

$AutomationMode = [Environment]::GetEnvironmentVariable(
    "EDU_DEPLOY_MODE",
    [EnvironmentVariableTarget]::Process
)

$UseAutomation = -not [string]::IsNullOrWhiteSpace($AutomationMode)

if ($UseAutomation) {
    $NormalizedMode = $AutomationMode.Trim().ToUpperInvariant()

    switch ($NormalizedMode) {
        "NEWG" {
            $Choice = "1"
        }

        "GAIA" {
            $Choice = "2"
        }

        "BOTH" {
            $Choice = "3"
        }

        "COMBINED" {
            $Choice = "3"
        }

        default {
            Clear-AutomationEnvironment
            Stop-Deploy (
                "Unsupported EDU_DEPLOY_MODE. Use NEWG, GAIA, BOTH, or COMBINED."
            )
        }
    }

    if ($Choice -in @("1", "3")) {
        $NewGUsername = Get-ProcessEnvBase64Text `
            -Name "EDU_NEWG_USERNAME_B64"

        $NewGPassword = Get-ProcessEnvBase64Text `
            -Name "EDU_NEWG_PASSWORD_B64"
    }

    if ($Choice -in @("2", "3")) {
        $GaiaUsername = Get-ProcessEnvBase64Text `
            -Name "EDU_GAIA_USERNAME_B64"

        $GaiaPassword = Get-ProcessEnvBase64Text `
            -Name "EDU_GAIA_PASSWORD_B64"
    }

    Clear-AutomationEnvironment

    if (
        $Choice -in @("1", "3") -and
        (
            [string]::IsNullOrWhiteSpace($NewGUsername) -or
            [string]::IsNullOrEmpty($NewGPassword)
        )
    ) {
        Stop-Deploy "NEWG automation credentials are missing."
    }

    if (
        $Choice -in @("2", "3") -and
        (
            [string]::IsNullOrWhiteSpace($GaiaUsername) -or
            [string]::IsNullOrEmpty($GaiaPassword)
        )
    ) {
        Stop-Deploy "GAIA automation credentials are missing."
    }

    Write-Host "Automation handoff detected." -ForegroundColor Green
    Write-Host ("Requested mode: " + $NormalizedMode) -ForegroundColor Cyan
    Write-Host "Software selection and credential prompts will be skipped."
    Write-Host ""
}
else {
    Write-Host "Select software:"
    Write-Host ""
    Write-Host " 1. NEWG"
    Write-Host " 2. GAIA"
    Write-Host " 3. NEWG + GAIA"
    Write-Host ""

    while ($Choice -notin @("1", "2", "3")) {
        $Choice = Read-Host "Select [1-3]"
    }

    if ($Choice -in @("1", "3")) {
        Write-Host ""
        Write-Host "NEWG credentials" -ForegroundColor Cyan

        $NewGUsername = Read-Host "NEWG username"

        if ([string]::IsNullOrWhiteSpace($NewGUsername)) {
            Write-Host "[ERROR] NEWG username cannot be empty." -ForegroundColor Red
            exit 1
        }

        $Secure = Read-Host "NEWG password" -AsSecureString
        $NewGPassword = Convert-SecureToPlainText -SecureValue $Secure

        if ([string]::IsNullOrEmpty($NewGPassword)) {
            Write-Host "[ERROR] NEWG password cannot be empty." -ForegroundColor Red
            exit 1
        }
    }

    if ($Choice -in @("2", "3")) {
        Write-Host ""
        Write-Host "GAIA credentials" -ForegroundColor Cyan

        $GaiaUsername = Read-Host "GAIA username"

        if ([string]::IsNullOrWhiteSpace($GaiaUsername)) {
            Write-Host "[ERROR] GAIA username cannot be empty." -ForegroundColor Red
            exit 1
        }

        $Secure = Read-Host "GAIA password" -AsSecureString
        $GaiaPassword = Convert-SecureToPlainText -SecureValue $Secure

        if ([string]::IsNullOrEmpty($GaiaPassword)) {
            Write-Host "[ERROR] GAIA password cannot be empty." -ForegroundColor Red
            exit 1
        }
    }
}

switch ($Choice) {
    "1" {
        $PackageType = "NEWG"
        $SelectedLabel = "NEWG"
    }

    "2" {
        $PackageType = "GAIA"
        $SelectedLabel = "GAIA"
    }

    "3" {
        $PackageType = "COMBINED"
        $SelectedLabel = "NEWG + GAIA"
    }
}

$InstallNoticeProcess = $null
$ResultLines = @()

try {
    $InstallNoticeProcess = Start-InstallNotice `
        -MessageBase64 $InstallNoticeBase64

    $Package = Get-LatestPackage -PackageType $PackageType

    $RequiredBytes = [int64](
        ($Package.Size * 4) + 512MB
    )

    $InstallBase = Resolve-InstallBase `
        -RequiredBytes $RequiredBytes

    $CacheRoot = Join-Path $InstallBase "_EducationDeployCache"

    New-Item `
        -ItemType Directory `
        -Path $CacheRoot `
        -Force |
        Out-Null

    $ZipPath = Join-Path $CacheRoot $Package.Name

    $ResultLines += ("Selected package : " + $SelectedLabel)
    $ResultLines += ("Package version  : " + $Package.Version)
    $ResultLines += ("Install base     : " + $InstallBase)

    Download-GoogleDriveFile `
        -FileId $Package.Id `
        -Destination $ZipPath `
        -ExpectedSize $Package.Size

    $ResultLines += "Download         : OK"
    $ResultLines += "ZIP validation   : OK"

    $NewGExe = $null
    $GaiaExe = $null

    if ($Choice -in @("1", "3")) {
        $NewGDir = Join-Path $InstallBase "NewG"

        $NewGExe = Extract-AppFromZip `
            -ZipPath $ZipPath `
            -AppType "NEWG" `
            -Destination $NewGDir

        $ResultLines += "NEWG extraction  : OK"
    }

    if ($Choice -in @("2", "3")) {
        $GaiaDir = Join-Path $InstallBase "GAIA"

        $GaiaExe = Extract-AppFromZip `
            -ZipPath $ZipPath `
            -AppType "GAIA" `
            -Destination $GaiaDir

        $ResultLines += "GAIA extraction  : OK"
    }

    $VcResult = Ensure-VCRuntimeX86 `
        -CacheRoot $CacheRoot

    if ($VcResult.InstalledNow) {
        $ResultLines += "Visual C++ x86   : INSTALLED"
    }
    else {
        $ResultLines += "Visual C++ x86   : OK"
    }

    if ($VcResult.Version) {
        $ResultLines += ("VC++ version     : " + $VcResult.Version)
    }

    if ($Choice -in @("1", "3")) {
        $NewGShortcut = New-DesktopShortcut `
            -ShortcutName "NewG" `
            -TargetPath $NewGExe

        $ResultLines += "NEWG shortcut    : OK"
    }

    if ($Choice -in @("2", "3")) {
        $GaiaShortcut = New-DesktopShortcut `
            -ShortcutName "GAIA" `
            -TargetPath $GaiaExe

        $ResultLines += "GAIA shortcut    : OK"
    }

    Stop-InstallNotice -Process $InstallNoticeProcess
    $InstallNoticeProcess = $null

    if ($Choice -in @("1", "3")) {
        $NewGLogin = Invoke-AppLogin `
            -AppName "NEWG" `
            -ExePath $NewGExe `
            -ProcessName "NewG" `
            -Username $NewGUsername `
            -Password $NewGPassword

        if (-not $NewGLogin.Verified) {
            Stop-Deploy (
                "NEWG login was not visually verified. Maximum screen change: " +
                $NewGLogin.MaxChange +
                " percent."
            )
        }

        $ResultLines += (
            "NEWG login       : VERIFIED (" +
            $NewGLogin.MaxChange +
            "% max change)"
        )
    }

    if ($Choice -in @("2", "3")) {
        $GaiaLogin = Invoke-AppLogin `
            -AppName "GAIA" `
            -ExePath $GaiaExe `
            -ProcessName "GaiaClient" `
            -Username $GaiaUsername `
            -Password $GaiaPassword

        if (-not $GaiaLogin.Verified) {
            Stop-Deploy (
                "GAIA login was not visually verified. Maximum screen change: " +
                $GaiaLogin.MaxChange +
                " percent."
            )
        }

        $ResultLines += (
            "GAIA login       : VERIFIED (" +
            $GaiaLogin.MaxChange +
            "% max change)"
        )
    }

    if ($Choice -in @("1", "3")) {
        if (
            -not (Test-Path -LiteralPath $NewGExe) -or
            -not (Test-Path -LiteralPath $NewGShortcut)
        ) {
            Stop-Deploy "Final NEWG validation failed."
        }
    }

    if ($Choice -in @("2", "3")) {
        if (
            -not (Test-Path -LiteralPath $GaiaExe) -or
            -not (Test-Path -LiteralPath $GaiaShortcut)
        ) {
            Stop-Deploy "Final GAIA validation failed."
        }
    }

    $ResultLines += "Final validation  : PASS"

    $SuccessDetails = $ResultLines -join [Environment]::NewLine

    $ConsoleHandle = [EduDeployNative]::GetConsoleWindow()
    if ($ConsoleHandle -ne [IntPtr]::Zero) {
        [EduDeployNative]::ShowWindow(
            $ConsoleHandle,
            [EduDeployNative]::SW_RESTORE
        ) | Out-Null
    }

    Clear-Host
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "       DEPLOYMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""

    foreach ($Line in $ResultLines) {
        Write-Host $Line
    }

    Write-Host ""
    Write-Host "All selected applications were verified." -ForegroundColor Green
    Write-Host "The deployment files will be removed after the success dialog is closed."
    Write-Host ""

    Show-ResultDialog `
        -Title "Installation Complete" `
        -IntroBase64 $SuccessNoticeBase64 `
        -Details $SuccessDetails

    Write-Host "[FINAL] Arming self-delete..." -ForegroundColor Yellow
    Arm-SelfDelete
    Write-Host "[FINAL] Self-delete helper started." -ForegroundColor Green
    Write-Host "[FINAL] Exiting deployment script..." -ForegroundColor Green

    Start-Sleep -Milliseconds 700
    exit 0
}
catch {
    Stop-InstallNotice -Process $InstallNoticeProcess

    try {
        $FailureConsole = [EduDeployNative]::GetConsoleWindow()
        if ($FailureConsole -ne [IntPtr]::Zero) {
            [EduDeployNative]::ShowWindow(
                $FailureConsole,
                [EduDeployNative]::SW_RESTORE
            ) | Out-Null
        }
    }
    catch {
    }

    $FailureDetails = @(
        "Deployment status : FAILED"
        ""
        ("Reason: " + $_.Exception.Message)
        ""
        "The deployment script was NOT deleted."
        "You can correct the problem and run it again."
    ) -join [Environment]::NewLine

    try {
        Show-ResultDialog `
            -Title "Installation Not Completed" `
            -IntroBase64 $FailureNoticeBase64 `
            -Details $FailureDetails
    }
    catch {
    }

    Write-Host ""
    Write-Host "[ERROR] Deployment failed." -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host ""
    Write-Host "The script was not deleted."
    Write-Host ""

    Read-Host "Press Enter to close"
    exit 1
}
finally {
    Stop-InstallNotice -Process $InstallNoticeProcess
}
