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
	$moduleRoot = 'C:\Program Files\WindowsPowerShell\Modules'
	$modulesToImport = @('PackageManagement', 'PowerShellGet', $moduleName)
	foreach ($requiredModule in $modulesToImport) {
		$moduleManifest = Get-ChildItem -LiteralPath (Join-Path $moduleRoot $requiredModule) -Filter "$requiredModule.psd1" -File -Recurse -ErrorAction SilentlyContinue |
			Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } -Descending |
			Select-Object -First 1
		if (-not $moduleManifest) {
			throw "$requiredModule.psd1 was not found under $moduleRoot. Run the module installation steps before this BIOS update script."
		}
		Import-Module -Name $moduleManifest.FullName -Force -ErrorAction Stop
		Write-Host "Imported $requiredModule from $($moduleManifest.FullName)." -ForegroundColor Green
	}

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