#Requires -Version 7.4
<#
.SYNOPSIS
    Installs the OEM PowerShell module for the current computer manufacturer.

.DESCRIPTION
    PowerShell 7 version. Detects the manufacturer, installs the matching
    module from PSGallery for all users with PSResourceGet, and imports it.

    Panasonic - PanasonicCommandUpdate
    HP        - HPCMSL and OEMWrapPS
    Lenovo    - Lenovo.Client.Update
    Dell      - OEMWrapPS

.NOTES
    Run as Administrator or ConfigMgr SYSTEM in PowerShell 7.4 or later,
    which includes Microsoft.PowerShell.PSResourceGet.
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

try {
    if (-not (Get-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
        Write-Host 'Registering the default PowerShell Gallery repository...' -ForegroundColor Cyan
        Register-PSResourceRepository -PSGallery -ErrorAction Stop
    }

    foreach ($moduleName in $moduleNames) {
        $installedModule = Get-InstalledPSResource -Name $moduleName -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $installedModule) {
            Write-Host "Installing $moduleName for $manufacturer..." -ForegroundColor Cyan
            $installParameters = @{
                Name = $moduleName
                Repository = 'PSGallery'
                Scope = 'AllUsers'
                TrustRepository = $true
                Quiet = $true
                ErrorAction = 'Stop'
            }

            if ($moduleName -eq 'HPCMSL') {
                $installParameters.AcceptLicense = $true
            }

            Install-PSResource @installParameters
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
    Write-Error "Failed to install or load required module(s) for $manufacturer. $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    #exit 1
}
