<#
.SYNOPSIS
    Finds and installs applicable Lenovo updates except BIOS updates.

.DESCRIPTION
    1. Confirms that Lenovo.Client.Update is installed and imports it.
    2. Retrieves updates applicable to this Lenovo system.
    3. Filters the results to applicable, not-installed updates excluding BIOS updates.
    4. Installs the matching updates and exports installation history to WMI.

.NOTES
    Run this script as Administrator. Some updates may require a restart.
#>

$moduleName = 'Lenovo.Client.Update'
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Write-Host "The required PowerShell module '$moduleName' is not installed. Attempting to install it from PSGallery..." -ForegroundColor Yellow
    try {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name $moduleName -Scope AllUsers -Force -AllowClobber -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-Error "The required PowerShell module '$moduleName' could not be installed. Run this script as Administrator or install it manually with: Install-Module -Name $moduleName -Scope AllUsers. $($_.Exception.Message)"
        return
    }
}

try {
    Import-Module -Name $moduleName -ErrorAction Stop
}
catch {
    Write-Error "The required PowerShell module '$moduleName' could not be imported. $($_.Exception.Message)"
    return
}

$updates = Get-LnvUpdate

$updatesToInstall = $updates | Where-Object {
    $_.Category -notmatch 'BIOS' -and
    $_.IsApplicable -eq $true -and
    $_.IsInstalled -ne $true
}

if (-not $updatesToInstall) {
    Write-Host "No applicable non-BIOS updates available."
    return
}

Write-Host "Applicable non-BIOS updates available."
$updatesToInstall | Install-LnvUpdate `
    -ExportToWMI `
    -Verbose