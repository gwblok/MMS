<#
.SYNOPSIS
	Installs applicable Panasonic updates except BIOS updates.

.NOTES
	Uses PanasonicCommandUpdate natively in Windows PowerShell 5.1.
	Panasonic documents OnlyDrivers as the non-BIOS update category.
#>

$ErrorActionPreference = 'Stop'
$moduleName = 'PanasonicCommandUpdate'

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

	Write-Host 'Installing applicable Panasonic non-BIOS updates...' -ForegroundColor Cyan
	Install-PanasonicUpdate -Category OnlyDrivers -AcceptLicense -Force -Verbose
}
catch {
	Write-Error "Failed to install Panasonic non-BIOS updates. $($_.Exception.Message)"
	exit 0
}
