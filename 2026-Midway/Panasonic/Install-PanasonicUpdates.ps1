$ErrorActionPreference = 'Stop'

$moduleName = 'PanasonicCommandUpdate'
$moduleRoot = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
$moduleDirectory = Join-Path $moduleRoot $moduleName
$moduleManifest = Get-ChildItem -LiteralPath $moduleDirectory -Filter "$moduleName.psd1" -File -Recurse -ErrorAction SilentlyContinue |
	Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } -Descending |
	Select-Object -First 1

if (-not $moduleManifest) {
	throw "$moduleName.psd1 was not found under $moduleDirectory. Install the module before running this script."
}

Import-Module -Name $moduleManifest.FullName -Force -ErrorAction Stop
Install-PanasonicUpdate -Category All -AcceptLicense -Force -Verbose
