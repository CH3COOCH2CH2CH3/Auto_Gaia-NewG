@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Education Deployment Bootstrap

rem ============================================================
rem EDIT THESE TWO VALUES ONCE BEFORE PUSHING THIS REPOSITORY.
rem The repository must be public for token-free endpoint access.
rem ============================================================
set "GITHUB_OWNER=CH3COOCH2CH2CH3"
set "GITHUB_REPO=Auto_Gaia-NewG"
set "GITHUB_BRANCH=main"

if /I "%GITHUB_OWNER%"=="YOUR_GITHUB_USERNAME" (
    echo.
    echo [ERROR] bootstrap.cmd is not configured.
    echo Edit GITHUB_OWNER before publishing the repository.
    echo.
    pause
    exit /b 10
)

set "RAW_BASE=https://raw.githubusercontent.com/%GITHUB_OWNER%/%GITHUB_REPO%/%GITHUB_BRANCH%"
set "WORK_DIR=%TEMP%\EducationDeploy"
set "MANIFEST_PATH=%WORK_DIR%\version.json"
set "SCRIPT_PATH=%WORK_DIR%\Deploy-Education.ps1"

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%" >nul 2>&1

echo.
echo =============================================
echo        EDUCATION DEPLOYMENT BOOTSTRAP
echo =============================================
echo.
echo [1/4] Downloading release manifest...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "$ProgressPreference='SilentlyContinue';" ^
 "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
 "$u='%RAW_BASE%/release/version.json?cb=' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds();" ^
 "Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile '%MANIFEST_PATH%'"

if errorlevel 1 (
    echo.
    echo [ERROR] Could not download version.json.
    echo Check Internet access and the GitHub repository settings.
    echo.
    pause
    exit /b 20
)

echo [2/4] Downloading and validating deployment script...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "$ProgressPreference='SilentlyContinue';" ^
 "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
 "$m=Get-Content -LiteralPath '%MANIFEST_PATH%' -Raw ^| ConvertFrom-Json;" ^
 "if($m.schema -ne 1){throw 'Unsupported manifest schema.'};" ^
 "if($m.ready -ne $true){throw 'Release is not marked ready.'};" ^
 "$n=[IO.Path]::GetFileName([string]$m.script);" ^
 "if([string]::IsNullOrWhiteSpace($n) -or $n -ne [string]$m.script){throw 'Invalid script name in manifest.'};" ^
 "$dest=Join-Path '%WORK_DIR%' $n;" ^
 "Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue;" ^
 "$u='%RAW_BASE%/release/' + $n + '?cb=' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds();" ^
 "Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $dest;" ^
 "$actualSize=(Get-Item -LiteralPath $dest).Length;" ^
 "if($m.size -and $actualSize -ne [int64]$m.size){Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue;throw ('File size mismatch. Expected ' + $m.size + ', got ' + $actualSize)};" ^
 "$actual=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToUpperInvariant();" ^
 "$expected=([string]$m.sha256).ToUpperInvariant();" ^
 "if($actual -ne $expected){Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue;throw ('SHA256 mismatch. Expected ' + $expected + ', got ' + $actual)};" ^
 "Write-Host ('[OK] Version: ' + $m.version);" ^
 "if($m.build){Write-Host ('[OK] Build  : ' + $m.build)};" ^
 "Write-Host ('[OK] Size   : ' + $actualSize + ' bytes');" ^
 "Write-Host ('[OK] SHA256 : ' + $actual)"

if errorlevel 1 (
    echo.
    echo [ERROR] Release download or SHA256 validation failed.
    echo The deployment script was NOT started.
    echo.
    pause
    exit /b 30
)

echo [3/4] Starting deployment...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
set "DEPLOY_EXIT=%ERRORLEVEL%"

echo.
echo [4/4] Deployment process returned exit code %DEPLOY_EXIT%.

if not "%DEPLOY_EXIT%"=="0" (
    echo.
    echo The deployment script was kept in:
    echo %SCRIPT_PATH%
    echo.
    echo This is intentional so the failure can be debugged.
    pause
)

endlocal & exit /b %DEPLOY_EXIT%
