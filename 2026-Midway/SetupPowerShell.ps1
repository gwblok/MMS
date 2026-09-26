<#
.SYNOPSIS
	Configures PSGallery as a trusted PowerShell repository.

.DESCRIPTION
    Installs or verifies the NuGet package provider in the current Windows
    PowerShell 5.1 session, installs or verifies PackageManagement and
    PowerShellGet, imports them, and configures PSGallery as trusted.

.NOTES
    Run elevated when installing the NuGet provider for all users.
#>

if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
}
else {
    $WindowsPhase = 'Windows'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Install-Nuget {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        $NuGetClientSourceURL = 'https://nuget.org/nuget.exe'
        $NuGetExeName = 'NuGet.exe'
        $PSGetProgramDataPath = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
        $nugetExeBasePath = $PSGetProgramDataPath
        $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
        
        if (-not (Test-Path -Path $nugetExeFilePath)) {
            if (-not (Test-Path -Path $nugetExeBasePath)) {
                $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            Write-Host -ForegroundColor Yellow "[-] Downloading NuGet to $nugetExeFilePath"
            $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
        }
        
        $PSGetAppLocalPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
        $nugetExeBasePath = $PSGetAppLocalPath
        $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
        if (-not (Test-Path -Path $nugetExeFilePath)) {
            if (-not (Test-Path -Path $nugetExeBasePath)) {
                $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            Write-Host -ForegroundColor Yellow "[-] Downloading NuGet to $nugetExeFilePath"
            $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
        }
        if (Test-Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll") {
            Write-Host -ForegroundColor Green "[+] Nuget 2.8.5.208+"
        }
        else {
            Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider NuGet -MinimumVersion 2.8.5.201"
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -Confirm:$false -ErrorAction Stop | Out-Null
        }
    }
    else {
        if (Test-Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll") {
            #Write-Host -ForegroundColor Green "[+] Nuget 2.8.5.208+"
        }
        else {
            Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider NuGet -MinimumVersion 2.8.5.201"
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -Confirm:$false -ErrorAction Stop | Out-Null
        }
        $InstalledModule = Get-PackageProvider -Name NuGet | Where-Object {$_.Version -ge '2.8.5.201'} | Sort-Object Version -Descending | Select-Object -First 1
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] NuGet $([string]$InstalledModule.Version)"
        }
    }
}
function Install-PackageManagement {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        $InstalledModule = Import-Module PackageManagement -PassThru -ErrorAction Ignore
        if (-not $InstalledModule) {
            Write-Host -ForegroundColor Yellow "[-] Install PackageManagement 1.4.8.1"
            $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.8.1.nupkg"
            Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "C:\Windows\Temp\packagemanagement.1.4.8.1.zip"
            $null = New-Item -Path "C:\Windows\Temp\1.4.8.1" -ItemType Directory -Force
            Expand-Archive -Path "C:\Windows\Temp\packagemanagement.1.4.8.1.zip" -DestinationPath "C:\Windows\Temp\1.4.8.1"
            $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
            Move-Item -Path "C:\Windows\Temp\1.4.8.1" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.8.1"
            Import-Module PackageManagement -Force -Scope Global
        }

        if (-not (Get-Module -Name PowerShellGet -ListAvailable | Where-Object { $_.Version -ge '2.2.5' })) {
            Write-Host -ForegroundColor Yellow "[-] Install PowerShellGet 2.2.5 directly"
            $PowerShellGetURL = 'https://psg-prod-eastus.azureedge.net/packages/powershellget.2.2.5.nupkg'
            $PowerShellGetZip = Join-Path 'C:\Windows\Temp' 'powershellget.2.2.5.zip'
            $PowerShellGetExtract = Join-Path 'C:\Windows\Temp' 'PowerShellGet-2.2.5'
            Invoke-WebRequest -UseBasicParsing -Uri $PowerShellGetURL -OutFile $PowerShellGetZip -ErrorAction Stop
            New-Item -Path $PowerShellGetExtract -ItemType Directory -Force | Out-Null
            Expand-Archive -Path $PowerShellGetZip -DestinationPath $PowerShellGetExtract -Force
            $PowerShellGetDestination = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\PowerShellGet\2.2.5'
            New-Item -Path $PowerShellGetDestination -ItemType Directory -Force | Out-Null
            Copy-Item -Path (Join-Path $PowerShellGetExtract '*') -Destination $PowerShellGetDestination -Recurse -Force
            Import-Module PowerShellGet -Force -Scope Global -ErrorAction Stop
        }
    }
    else {
        Import-Module PackageManagement -Force -Scope Global -ErrorAction Stop
        Import-Module PowerShellGet -Force -Scope Global -ErrorAction Stop

        $InstalledModule = Get-Module -Name PackageManagement -ListAvailable | Where-Object {$_.Version -ge '1.4.8.1'} | Sort-Object Version -Descending | Select-Object -First 1
        if (-not ($InstalledModule)) {
            Write-Host -ForegroundColor Yellow "[-] Install-Module PackageManagement -MinimumVersion 1.4.8.1"
            Install-Module -Name PackageManagement -MinimumVersion 1.4.8.1 -Force -Confirm:$false -Source PSGallery -Scope AllUsers -ErrorAction Stop | Out-Null
            Import-Module PackageManagement -Force -Scope Global -ErrorAction Stop
        }

        $InstalledModule = Get-Module -Name PackageManagement -ListAvailable | Where-Object {$_.Version -ge '1.4.8.1'} | Sort-Object Version -Descending | Select-Object -First 1
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] PackageManagement $([string]$InstalledModule.Version)"
        }

        $InstalledModule = Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'} | Sort-Object Version -Descending | Select-Object -First 1
        if (-not ($InstalledModule)) {
            Write-Host -ForegroundColor Yellow "[-] Install-Module PowerShellGet -MinimumVersion 2.2.5"
            Install-Module -Name PowerShellGet -MinimumVersion 2.2.5 -Repository PSGallery -Force -Scope AllUsers -AllowClobber -Confirm:$false -ErrorAction Stop | Out-Null
            Import-Module PowerShellGet -Force -Scope Global -ErrorAction Stop
        }

        Import-Module PowerShellGet -Force -Scope Global -ErrorAction Stop
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] PowerShellGet $([string]$InstalledModule.Version)"
        }
    }
}

try {
    $ErrorActionPreference = 'Stop'
    Write-Host 'Configuring PSGallery in the current Windows PowerShell session...' -ForegroundColor Cyan
    Install-Nuget
    Import-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
    Install-PackageManagement
    Import-Module PackageManagement -Force -Scope Global -ErrorAction Stop
    Import-Module PowerShellGet -Force -Scope Global -ErrorAction Stop
    $repository = Get-PSRepository -Name PSGallery -ErrorAction Stop
    if ($repository.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    }
    Write-Host 'NuGet is installed and PSGallery is trusted in Windows PowerShell 5.1.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Failed to configure NuGet or PSGallery in Windows PowerShell 5.1. $($_.Exception.Message)"
    exit 1
}
