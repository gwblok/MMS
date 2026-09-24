<#
.SYNOPSIS
	Installs and verifies the OEMWrapPS PowerShell module.

.DESCRIPTION
	Trusts PSGallery, installs OEMWrapPS for all users, imports the module,
	and verifies that the module is loaded in the current PowerShell session.

.NOTES
	Run as Administrator when using AllUsers installation scope. This script
	is suitable for ConfigMgr running as SYSTEM.
#>

$pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
if (-not (Test-Path -Path $pwshPath)) {
	$pwshCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
	if ($pwshCommand) {
		$pwshPath = $pwshCommand.Source
	}
}

if (-not (Test-Path -Path $pwshPath)) {
	Write-Error 'PowerShell 7 (pwsh.exe) was not found. Install PowerShell 7 before running this script.'
	exit 1
}

$ps7Script = @'
$ErrorActionPreference = 'Stop'
$moduleName = 'OEMWrapPS'
$targetModulePath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'

try {
    New-Item -Path $targetModulePath -ItemType Directory -Force | Out-Null
    if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
        $repository = Get-PSResourceRepository -Name PSGallery -ErrorAction Stop
        if (-not $repository.Trusted) {
            Set-PSResourceRepository -Name PSGallery -Trusted
        }

        $installedModule = Get-Module -ListAvailable -Name $moduleName |
            Where-Object { $_.ModuleBase -like "$(Join-Path $targetModulePath $moduleName)*" } |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $installedModule) {
            Write-Host "Installing $moduleName from PSGallery with PSResourceGet..." -ForegroundColor Cyan
            Save-PSResource -Name $moduleName -Repository PSGallery -Path $targetModulePath -TrustRepository -Quiet
        }
    }
    else {
        $gallery = Get-PSRepository -Name PSGallery -ErrorAction Stop
        if ($gallery.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }

        $installedModule = Get-Module -ListAvailable -Name $moduleName |
            Where-Object { $_.ModuleBase -like "$(Join-Path $targetModulePath $moduleName)*" } |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $installedModule) {
            Write-Host "Installing $moduleName from PSGallery with PowerShellGet..." -ForegroundColor Cyan
            Save-Module -Name $moduleName -Repository PSGallery -Path $targetModulePath -Force -Confirm:$false
        }
    }

    $installedModule = Get-Module -ListAvailable -Name $moduleName |
        Where-Object { $_.ModuleBase -like "$(Join-Path $targetModulePath $moduleName)*" } |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if (-not $installedModule) {
        throw "The module was not found in $targetModulePath."
    }

    Import-Module -Name $installedModule.Path -Force
    $loadedModule = Get-Module -Name $moduleName
    if (-not $loadedModule) {
        throw "The module was installed but is not loaded in the PS7 session."
    }

    Write-Host "$moduleName $($loadedModule.Version) loaded successfully in PowerShell $($PSVersionTable.PSVersion)." -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Failed to install or load $moduleName in PowerShell 7. $($_.Exception.Message)"
    exit 1
}
'@

$childScriptPath = Join-Path $env:TEMP ("Install-OEMWrapPS-PS7-{0}.ps1" -f [guid]::NewGuid())
try {
	Set-Content -Path $childScriptPath -Value $ps7Script -Encoding UTF8 -Force
	Write-Host "Handing OEMWrapPS installation to PowerShell 7: $pwshPath" -ForegroundColor Cyan
	& $pwshPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $childScriptPath
	$exitCode = $LASTEXITCODE
}
finally {
    try {
        Remove-Item -LiteralPath $childScriptPath -Force -ErrorAction Stop
    }
    catch {
        # Cleanup failure must not mask the PS7 installation result.
    }
}

exit $exitCode
