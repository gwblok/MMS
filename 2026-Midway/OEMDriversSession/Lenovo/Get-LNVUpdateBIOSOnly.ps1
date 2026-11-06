<#
.SYNOPSIS
    Finds and installs applicable Lenovo BIOS updates.

.DESCRIPTION
    1. Confirms that Lenovo.Client.Update is installed and imports it.
    2. Retrieves updates applicable to this Lenovo system.
    3. Filters the results to BIOS updates that are applicable and not installed.
    4. Installs the matching BIOS updates and records BIOS/WMI tracking information.

.NOTES
    Run this script as Administrator. BIOS updates may require a restart.
#>
#Connects to TS Environment and Creates (confirms) Registry Stucture in place for the Win10 Upgrade Build.
try {
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    Write-Host "Connected to TS Environment." -ForegroundColor Green
}
catch {
    Write-Host "Not connected to TS Environment." -ForegroundColor yellow
}

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

$biosUpdates = $updates | Where-Object {
    $_.Category -match 'BIOS' -and
    $_.IsApplicable -eq $true -and
    $_.IsInstalled -ne $true
}

if (-not $biosUpdates) {
    Write-Host "No applicable BIOS updates available."
    return
}

Write-Host "Applicable BIOS updates available."
$biosUpdates | Install-LnvUpdate `
    -SaveBIOSUpdateInfoToRegistry `
    -ExportToWMI `
    -Verbose

if ($Tsenv) {
    $tsenv.Value('BIOSRebootRequired') = $true
}