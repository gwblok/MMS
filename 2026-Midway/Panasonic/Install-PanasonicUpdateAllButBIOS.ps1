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
	$moduleRoot = 'C:\Program Files\WindowsPowerShell\Modules'
	$modulesToImport = @('PackageManagement', 'PowerShellGet', $moduleName)
	foreach ($requiredModule in $modulesToImport) {
		$moduleManifest = Get-ChildItem -LiteralPath (Join-Path $moduleRoot $requiredModule) -Filter "$requiredModule.psd1" -File -Recurse -ErrorAction SilentlyContinue |
			Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } -Descending |
			Select-Object -First 1
		if (-not $moduleManifest) {
			throw "$requiredModule.psd1 was not found under $moduleRoot. Run the module installation steps before this update script."
		}
		Import-Module -Name $moduleManifest.FullName -Force -ErrorAction Stop
		Write-Host "Imported $requiredModule from $($moduleManifest.FullName)." -ForegroundColor Green
	}

	Write-Host 'Installing applicable Panasonic non-BIOS updates...' -ForegroundColor Cyan
	Install-PanasonicUpdate -Category OnlyDrivers -AcceptLicense -Force -Verbose
}
catch {
	Write-Error "Failed to install Panasonic non-BIOS updates. $($_.Exception.Message)"
	exit 0
}
