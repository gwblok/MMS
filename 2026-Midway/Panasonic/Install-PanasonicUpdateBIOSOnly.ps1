<#
.SYNOPSIS
	Installs applicable Panasonic BIOS updates.

.NOTES
	Uses PanasonicCommandUpdate natively in Windows PowerShell 5.1.
#>

$ErrorActionPreference = 'Stop'
$moduleName = 'PanasonicCommandUpdate'
$tsenv = $null
$currentStep = 'Initialize diagnostics'

function Write-BiosUpdateLog {
	param (
		[Parameter(Mandatory)]
		[string]$Message,
		[ValidateSet('INFO', 'WARN', 'ERROR')]
		[string]$Level = 'INFO'
	)

	$entry = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
	Write-Host $entry
}

try {
	$currentStep = 'Connect to Configuration Manager Task Sequence environment'
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    Write-BiosUpdateLog -Message 'Connected to Task Sequence environment.'
}
catch {
    Write-BiosUpdateLog -Level WARN -Message "Could not connect to Task Sequence environment: $($_.Exception.Message)"
}

try {
	$currentStep = 'Initialize diagnostics'
	Write-BiosUpdateLog -Message "Starting Panasonic BIOS update. Computer: $env:COMPUTERNAME; PowerShell: $($PSVersionTable.PSVersion); detailed output is written to the task sequence log."

	$currentStep = 'Locate installed PowerShell module manifests'
	$moduleRoot = 'C:\Program Files\WindowsPowerShell\Modules'
	$modulesToImport = @('PackageManagement', 'PowerShellGet', $moduleName)
	Write-BiosUpdateLog -Message "Module search root: $moduleRoot"
	foreach ($requiredModule in $modulesToImport) {
		$currentStep = "Find $requiredModule manifest"
		$moduleDirectory = Join-Path $moduleRoot $requiredModule
		Write-BiosUpdateLog -Message "Searching '$moduleDirectory' for $requiredModule.psd1"
		$moduleManifest = Get-ChildItem -LiteralPath $moduleDirectory -Filter "$requiredModule.psd1" -File -Recurse -ErrorAction SilentlyContinue |
			Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } -Descending |
			Select-Object -First 1
		if (-not $moduleManifest) {
			throw "$requiredModule.psd1 was not found under '$moduleDirectory'. Run the module installation steps before this BIOS update script."
		}
		$currentStep = "Import $requiredModule from $($moduleManifest.FullName)"
		Write-BiosUpdateLog -Message "Found manifest: $($moduleManifest.FullName); version directory: $($moduleManifest.Directory.Name)"
		Import-Module -Name $moduleManifest.FullName -Force -ErrorAction Stop
		Write-BiosUpdateLog -Message "Imported $requiredModule from $($moduleManifest.FullName)."
	}

	$currentStep = 'Check for latest Panasonic BIOS update'
	Write-BiosUpdateLog -Message 'Checking for the latest Panasonic BIOS update.'
	Write-BiosUpdateLog -Message "Detected model variable: $($tsenv.Value('Model'))"
	$currentStep = 'Run Install-PanasonicUpdate for BIOS updates'
	$installResult = Install-PanasonicUpdate -Category OnlyBios -AcceptLicense -Force -Verbose
	Write-BiosUpdateLog -Message "Install-PanasonicUpdate returned: $(($installResult | Out-String).Trim())"
	$rebootRequired = $false
	if ($installResult -and $installResult.PSObject.Properties['RebootRequired']) {
		$rebootRequired = [bool]$installResult.RebootRequired
	}
	Write-BiosUpdateLog -Message "Panasonic BIOS update reboot required: $rebootRequired"

	if ($tsenv -and $rebootRequired) {
		$currentStep = 'Set BIOS reboot-required Task Sequence variable'
		$tsenv.Value('BIOSRebootRequired') = $rebootRequired
		Write-BiosUpdateLog -Message 'Set Task Sequence variable BIOSRebootRequired to True.'
	}
	Write-BiosUpdateLog -Message 'Panasonic BIOS update script completed successfully.'
}
catch {
	$errorRecord = $_
	Write-BiosUpdateLog -Level ERROR -Message "Failed during step: $currentStep"
	Write-BiosUpdateLog -Level ERROR -Message "Exception: $($errorRecord.Exception.GetType().FullName): $($errorRecord.Exception.Message)"
	Write-BiosUpdateLog -Level ERROR -Message "FullyQualifiedErrorId: $($errorRecord.FullyQualifiedErrorId)"
	Write-BiosUpdateLog -Level ERROR -Message "Category: $($errorRecord.CategoryInfo)"
	if ($errorRecord.InvocationInfo) {
		Write-BiosUpdateLog -Level ERROR -Message "Command: $($errorRecord.InvocationInfo.Line)"
		Write-BiosUpdateLog -Level ERROR -Message "Script location: $($errorRecord.InvocationInfo.ScriptName), line $($errorRecord.InvocationInfo.ScriptLineNumber), column $($errorRecord.InvocationInfo.OffsetInLine)"
		Write-BiosUpdateLog -Level ERROR -Message "Position: $($errorRecord.InvocationInfo.PositionMessage)"
	}
	if ($errorRecord.ScriptStackTrace) {
		Write-BiosUpdateLog -Level ERROR -Message "Script stack: $($errorRecord.ScriptStackTrace)"
	}
	if ($errorRecord.Exception.InnerException) {
		Write-BiosUpdateLog -Level ERROR -Message "Inner exception: $($errorRecord.Exception.InnerException.GetType().FullName): $($errorRecord.Exception.InnerException.Message)"
	}
	Write-Warning "Failed during '$currentStep'. Full error details are shown above and should be available in smsts.log."
	exit 1
}