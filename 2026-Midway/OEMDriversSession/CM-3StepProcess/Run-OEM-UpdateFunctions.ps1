<#
.SYNOPSIS
    Detects the OEM (HP, Dell, Lenovo, Panasonic), imports the matching module
    installed by InstallModule-OEMByManufacturer.ps1, and runs the OEM update.

.NOTES
    Run as Administrator or ConfigMgr SYSTEM.
    Detection logic follows the DeployR MakeAlias / ModelAlias / SystemAlias code.
#>

$ErrorActionPreference = 'Stop'

# Determine OEM (same logic as DeployR MakeAlias)
$LocalInfo = @{}
$LocalInfo['Make'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer.Trim()
switch -Wildcard ($LocalInfo['Make']) {
    '*Hewlett-Packard*' {
        $LocalInfo['MakeAlias'] = 'HP'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()
        $LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName MS_SystemInformation -Namespace root\wmi).BaseBoardProduct.Trim()
    }
    '*HP*' {
        $LocalInfo['MakeAlias'] = 'HP'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()
        $LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName MS_SystemInformation -Namespace root\wmi).BaseBoardProduct.Trim()
    }
    '*Dell*' {
        $LocalInfo['MakeAlias'] = 'Dell'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()
        $LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName MS_SystemInformation -Namespace root\wmi).SystemSku.Trim()
    }
    '*Lenovo*' {
        $LocalInfo['MakeAlias'] = 'Lenovo'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).Version.Trim()
        $LocalInfo['SystemAlias'] = ((Get-CimInstance -ClassName Win32_ComputerSystem).Model.Substring(0, 4)).Trim()
    }
    '*Panasonic*' {
        $LocalInfo['MakeAlias'] = 'Panasonic Corporation'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()
        $LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName MS_SystemInformation -Namespace root\wmi).BaseBoardProduct.Trim()
    }
    default {
        $LocalInfo['MakeAlias'] = 'NA'
        $LocalInfo['ModelAlias'] = 'NA'
        $LocalInfo['SystemAlias'] = 'NA'
    }
}

Write-Host "Manufacturer: $($LocalInfo['Make']) | MakeAlias: $($LocalInfo['MakeAlias']) | Model: $($LocalInfo['ModelAlias']) | System: $($LocalInfo['SystemAlias'])" -ForegroundColor Cyan

switch ($LocalInfo['MakeAlias']) {
    'HP' {
        Import-Module -Name OEMWrapPS -Force -ErrorAction Stop
        Get-HPUpdate | Install-HPUpdate -Force
    }
    'Dell' {
        Import-Module -Name OEMWrapPS -Force -ErrorAction Stop
        Get-DellUpdate | Install-DellUpdate -Force
    }
    'Lenovo' {
        Import-Module -Name Lenovo.Client.Update -Force -ErrorAction Stop
        Get-LnvUpdate | Install-LnvUpdate
    }
    'Panasonic Corporation' {
        Import-Module -Name PanasonicCommandUpdate -Force -ErrorAction Stop
        Show-PanasonicUpdate -AcceptLicense | Install-PanasonicUpdate -AcceptLicense -Force
    }
    default {
        throw "Unsupported computer manufacturer: $($LocalInfo['Make'])"
    }
}
