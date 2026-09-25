<#
.SYNOPSIS
	Installs applicable Panasonic BIOS updates.

.NOTES
	Uses PanasonicCommandUpdate natively in Windows PowerShell 5.1.
#>

$ErrorActionPreference = 'Stop'
$moduleName = 'PanasonicCommandUpdate'
try {
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    Write-Host "Connected to TS Environment." -ForegroundColor Green
}
catch {
    Write-Host "Not connected to TS Environment." -ForegroundColor yellow
}

try {
	$nugetProvider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
		Sort-Object Version -Descending |
		Select-Object -First 1
	if (-not $nugetProvider -or $nugetProvider.Version -lt [version]'2.8.5.201') {
		Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -Confirm:$false | Out-Null
	}
	Import-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null

	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
	if (-not (Get-Module -ListAvailable -Name $moduleName)) {
		Install-Module -Name $moduleName -Repository PSGallery -Scope AllUsers -Force -AcceptLicense -Confirm:$false
	}
	Import-Module -Name $moduleName -Force

	Write-Host 'Installing applicable Panasonic BIOS updates...' -ForegroundColor Cyan
	$installResult = Install-PanasonicUpdate -Category OnlyBios -AcceptLicense -Force -Verbose
	$rebootRequired = $false
	if ($installResult -and $installResult.PSObject.Properties['RebootRequired']) {
		$rebootRequired = [bool]$installResult.RebootRequired
	}
	Write-Host "Panasonic BIOS update reboot required: $rebootRequired" -ForegroundColor Yellow
}
catch {
	Write-Error "Failed to install Panasonic BIOS updates. $($_.Exception.Message)"
	exit 0
}
if ($tsenv -and $rebootRequired) {
    $tsenv.Value('BIOSRebootRequired') = $rebootRequired
}