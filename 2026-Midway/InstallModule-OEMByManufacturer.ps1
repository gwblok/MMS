<#
.SYNOPSIS
    Installs the OEM PowerShell module for the current computer manufacturer.

.DESCRIPTION
    Native Windows PowerShell 5.1 version. Detects the manufacturer, installs
    the matching module from PSGallery for all users, and imports it.

    Panasonic - PanasonicCommandUpdate
    HP        - HPCMSL and OEMWrapPS
    Lenovo    - Lenovo.Client.Update
    Dell      - OEMWrapPS

.NOTES
    Run as Administrator or ConfigMgr SYSTEM.
#>

$ErrorActionPreference = 'Stop'

$manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$moduleNames = switch -Regex ($manufacturer) {
    'Panasonic' { @('PanasonicCommandUpdate'); break }
    'HP|Hewlett-Packard' { @('HPCMSL', 'OEMWrapPS'); break }
    'Lenovo' { @('Lenovo.Client.Update'); break }
    'Dell' { @('OEMWrapPS'); break }
    default { @() }
}

if ($moduleNames.Count -eq 0) {
    throw "Unsupported computer manufacturer: $manufacturer"
}

function Initialize-PSGallery {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Import-Module -Name PackageManagement -ErrorAction Stop
    Import-Module -Name PowerShellGet -ErrorAction Stop

    $repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if (-not $repository) {
        Write-Host 'Registering the default PowerShell Gallery repository...' -ForegroundColor Cyan
        Register-PSRepository -Default -ErrorAction Stop
        $repository = Get-PSRepository -Name PSGallery -ErrorAction Stop
    }

    if ($repository.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    }
}

try {
    Initialize-PSGallery

    $nugetProvider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $nugetProvider -or $nugetProvider.Version -lt [version]'2.8.5.201') {
        Write-Host 'Installing the NuGet package provider...' -ForegroundColor Cyan
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -Confirm:$false -ErrorAction Stop | Out-Null
    }

    Import-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null

    foreach ($moduleName in $moduleNames) {
        $installedModule = Get-Module -ListAvailable -Name $moduleName |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $installedModule) {
            Write-Host "Installing $moduleName for $manufacturer..." -ForegroundColor Cyan
            $installParameters = @{
                Name = $moduleName
                Repository = 'PSGallery'
                Scope = 'AllUsers'
                Force = $true
                AllowClobber = $true
                Confirm = $false
                ErrorAction = 'Stop'
            }

            if ($moduleName -eq 'HPCMSL') {
                $installParameters.AcceptLicense = $true
            }

            Install-Module @installParameters
        }
        else {
            Write-Host "$moduleName $($installedModule.Version) is already installed." -ForegroundColor Green
        }

        Import-Module -Name $moduleName -Force -ErrorAction Stop
        $loadedModule = Get-Module -Name $moduleName
        if (-not $loadedModule) {
            throw "$moduleName was installed but could not be imported."
        }

        Write-Host "$moduleName $($loadedModule.Version) loaded successfully for $manufacturer." -ForegroundColor Green
    }

    exit 0
}
catch {
    Write-Error "Failed to install or load required module(s) for $manufacturer. $($_.Exception.Message)"
    #exit 1
}
