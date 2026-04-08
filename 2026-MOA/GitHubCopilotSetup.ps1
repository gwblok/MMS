<# This script will install the latest versions of 
 - Git
 - GitHub CLI
 - Copilot CLI
 - Visual Studio Code
 - PowerShell 7

 Using MSI files where available

 References:
  https://github.com/cli/cli/releases/
  https://github.com/github/copilot-cli/releases
  https://github.com/gwblok/garytown/blob/master/Intune/Install-Git.ps1
  https://github.com/gwblok/garytown/blob/master/Intune/Install-VSCode.ps1
  https://github.com/gwblok/garytown/blob/master/Intune/Install-PowerShellMSI.ps1
#>

<# Created with Prompts

1st Prompt:
Create a script that will install the latest versions of

    Git
    GitHub CLI
    Copilot CLI
    Visual Studio Code
    PowerShell 7
    Using MSI files


    GitHub CLI info:
    https://github.com/cli/cli/releases/
    Copilot Release:
    https://github.com/github/copilot-cli/releases

    Scripts that might help:
    https://github.com/gwblok/garytown/blob/master/Intune/Install-Git.ps1
    https://github.com/gwblok/garytown/blob/master/Intune/Install-VSCode.ps1
    https://github.com/gwblok/garytown/blob/master/Intune/Install-PowerShellMSI.ps1

2nd Prompt:
    What went wrong there? Can you fix it?
    (Attached Screen Capture of the error)

3rd Prompt:
    It says it is installing 2.53.0.0 BUT it actually installed 2.53.0.2, so you're getting the wrong version from somewhere and it re-installs GIT each time. Can you fix that?
#>

#Requires -RunAsAdministrator

# ============================================================================
# Helper Functions
# ============================================================================

function Get-InstalledApps {
    if (![Environment]::Is64BitProcess) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | . { process { if ($_.DisplayName -and $_.UninstallString) { $_ } } } |
        Select-Object DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |
        Sort-Object DisplayName
}

# Ensure TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Create temp directory for downloads
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue

# Determine architecture
$architecture = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'x64' }

# ============================================================================
# 1. Git for Windows
# ============================================================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Checking Git for Windows..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$AppCurrentInstall = Get-InstalledApps | Where-Object { $_.DisplayName -eq "git" }
[version]$AppCurrentInstallVersion = if ($AppCurrentInstall) { $AppCurrentInstall.DisplayVersion } else { '0.0.0.1' }

$apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl -Method Get
$version = $release.tag_name
# Git tags are like v2.53.0.windows.2 — extract major.minor.patch and the revision after .windows.
$versionClean = $version -replace '^v', ''
$mainVersion = ($versionClean.split(".") | Select-Object -First 3) -join "."
$windowsRevision = if ($versionClean -match '\.windows\.(\d+)') { [int]$matches[1] } else { 0 }
[version]$NewRelease = [version]::new(([version]$mainVersion).Major, ([version]$mainVersion).Minor, ([version]$mainVersion).Build, $windowsRevision)
$downloadUrl = ($release.assets | Where-Object { $_.name -like "*64-bit.exe" }).browser_download_url
$packageName = ($release.assets | Where-Object { $_.name -like "*64-bit.exe" }).name

if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion) {
    Write-Host "Git already current: $NewRelease" -ForegroundColor Green
}
else {
    Write-Host "Installing Git $NewRelease..." -ForegroundColor Yellow
    $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
    Start-BitsTransfer -Source $downloadUrl -Destination $packagePath
    if (Test-Path -Path $packagePath) {
        $process = Start-Process $packagePath -ArgumentList /VERYSILENT -Wait -PassThru
        Write-Host "Git installed. Exit code: $($process.ExitCode)" -ForegroundColor Green
    }
}

# ============================================================================
# 2. GitHub CLI
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Checking GitHub CLI..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$AppCurrentInstall = Get-InstalledApps | Where-Object { $_.DisplayName -like "GitHub CLI*" }
[version]$AppCurrentInstallVersion = if ($AppCurrentInstall) { $AppCurrentInstall.DisplayVersion } else { '0.0.0.1' }

$apiUrl = "https://api.github.com/repos/cli/cli/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl -Method Get
$version = $release.tag_name -replace '^v', ''
[version]$NewRelease = $version
$NewRelease = [version]::new($NewRelease.Major, $NewRelease.Minor, $(if ($NewRelease.Build -eq -1) { 0 } else { $NewRelease.Build }), $(if ($NewRelease.Revision -eq -1) { 0 } else { $NewRelease.Revision }))
$msiPattern = if ($architecture -eq 'arm64') { "*windows_arm64.msi" } else { "*windows_amd64.msi" }
$downloadUrl = ($release.assets | Where-Object { $_.name -like $msiPattern }).browser_download_url
$packageName = ($release.assets | Where-Object { $_.name -like $msiPattern }).name

if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion) {
    Write-Host "GitHub CLI already current: $NewRelease" -ForegroundColor Green
}
else {
    Write-Host "Installing GitHub CLI $NewRelease..." -ForegroundColor Yellow
    $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
    Start-BitsTransfer -Source $downloadUrl -Destination $packagePath
    if (Test-Path -Path $packagePath) {
        $process = Start-Process msiexec -ArgumentList @("/i", $packagePath, "/quiet") -Wait -PassThru
        Write-Host "GitHub CLI installed. Exit code: $($process.ExitCode)" -ForegroundColor Green
    }
}

# ============================================================================
# 3. GitHub Copilot CLI
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Checking GitHub Copilot CLI..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$AppCurrentInstall = Get-InstalledApps | Where-Object { $_.DisplayName -like "*Copilot*" -and $_.Publisher -like "*GitHub*" }
[version]$AppCurrentInstallVersion = if ($AppCurrentInstall) { $AppCurrentInstall.DisplayVersion } else { '0.0.0.1' }

$apiUrl = "https://api.github.com/repos/github/copilot-cli/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl -Method Get
$version = $release.tag_name -replace '^v', ''
[version]$NewRelease = $version
$NewRelease = [version]::new($NewRelease.Major, $NewRelease.Minor, $(if ($NewRelease.Build -eq -1) { 0 } else { $NewRelease.Build }), $(if ($NewRelease.Revision -eq -1) { 0 } else { $NewRelease.Revision }))
$msiName = if ($architecture -eq 'arm64') { "copilot-arm64.msi" } else { "copilot-x64.msi" }
$downloadUrl = ($release.assets | Where-Object { $_.name -eq $msiName }).browser_download_url
$packageName = $msiName

if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion) {
    Write-Host "Copilot CLI already current: $NewRelease" -ForegroundColor Green
}
else {
    Write-Host "Installing Copilot CLI $NewRelease..." -ForegroundColor Yellow
    $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
    Start-BitsTransfer -Source $downloadUrl -Destination $packagePath
    if (Test-Path -Path $packagePath) {
        $process = Start-Process msiexec -ArgumentList @("/i", $packagePath, "/quiet") -Wait -PassThru
        Write-Host "Copilot CLI installed. Exit code: $($process.ExitCode)" -ForegroundColor Green
    }
}

# ============================================================================
# 4. Visual Studio Code (System Installer - EXE, no MSI available)
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Checking Visual Studio Code..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$AppCurrentInstall = Get-InstalledApps | Where-Object { $_.DisplayName -like "Microsoft Visual Studio Code*" }
[version]$AppCurrentInstallVersion = if ($AppCurrentInstall) { $AppCurrentInstall.DisplayVersion } else { '0.0.0.1' }

# Get latest version from the VS Code update API
$baseUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
try {
    $updateInfo = Invoke-RestMethod -Uri "https://update.code.visualstudio.com/api/update/win32-x64/stable/latest" -Method Get
    [version]$NewRelease = $updateInfo.productVersion
}
catch {
    Write-Host "Could not determine latest VS Code version, will attempt install." -ForegroundColor Yellow
    [version]$NewRelease = '999.0.0'
}

if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion) {
    Write-Host "VS Code already current: $NewRelease" -ForegroundColor Green
}
else {
    Write-Host "Installing VS Code $NewRelease..." -ForegroundColor Yellow
    $packageName = "VSCodeSetup-x64.exe"
    $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
    Start-BitsTransfer -Source $baseUrl -Destination $packagePath
    if (Test-Path -Path $packagePath) {
        $process = Start-Process $packagePath -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait -PassThru
        Write-Host "VS Code installed. Exit code: $($process.ExitCode)" -ForegroundColor Green
    }
}

# ============================================================================
# 5. PowerShell 7
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Checking PowerShell 7..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$AppCurrentInstall = Get-InstalledApps | Where-Object { $_.DisplayName -match "PowerShell 7" }
[version]$AppCurrentInstallVersion = if ($AppCurrentInstall) { $AppCurrentInstall.DisplayVersion } else { '0.0.0.1' }

$metadata = Invoke-RestMethod https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json
$releaseVersion = $metadata.ReleaseTag -replace '^v'
[Version]$NewRelease = $releaseVersion
$NewRelease = [version]::new($NewRelease.Major, $NewRelease.Minor, $(if ($NewRelease.Build -eq -1) { 0 } else { $NewRelease.Build }), $(if ($NewRelease.Revision -eq -1) { 0 } else { $NewRelease.Revision }))

if ([Version]$NewRelease -match [version]$AppCurrentInstallVersion) {
    Write-Host "PowerShell 7 already current: $NewRelease" -ForegroundColor Green
}
else {
    Write-Host "Installing PowerShell 7 $NewRelease..." -ForegroundColor Yellow
    $packageName = "PowerShell-${releaseVersion}-win-${architecture}.msi"
    $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/v${releaseVersion}/${packageName}"
    $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
    Start-BitsTransfer -Source $downloadUrl -Destination $packagePath
    if (Test-Path -Path $packagePath) {
        $MSIArguments = @(
            "/i", $packagePath, "/quiet",
            "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1",
            "ENABLE_PSREMOTING=1"
        )
        $process = Start-Process msiexec -ArgumentList $MSIArguments -Wait -PassThru
        Write-Host "PowerShell 7 installed. Exit code: $($process.ExitCode)" -ForegroundColor Green
    }
}

# ============================================================================
# Cleanup
# ============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Cleaning up temp files..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Done! All installations complete." -ForegroundColor Green

