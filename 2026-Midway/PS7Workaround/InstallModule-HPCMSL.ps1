<#
.SYNOPSIS
    Installs and imports the HP PowerShell modules.

.DESCRIPTION
    Hands installation of HPCMSL and OEMWrapPS to PowerShell 7, placing both
    modules in the all-users Windows PowerShell module path. Accepts the
    HPCMSL license and verifies that both modules load.

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
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$moduleNames = @('HPCMSL', 'OEMWrapPS')
$targetModulePath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'

try {
    New-Item -Path $targetModulePath -ItemType Directory -Force | Out-Null

    if (Get-Command Save-PSResource -ErrorAction SilentlyContinue) {
        $repository = Get-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue
        if (-not $repository) {
            Register-PSResourceRepository -PSGallery -ErrorAction Stop
            $repository = Get-PSResourceRepository -Name PSGallery -ErrorAction Stop
        }
        if (-not $repository.Trusted) {
            Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction Stop
        }
    }
    else {
        Import-Module PackageManagement -ErrorAction Stop
        Import-Module PowerShellGet -ErrorAction Stop
        $repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if (-not $repository) {
            Register-PSRepository -Default -ErrorAction Stop
            $repository = Get-PSRepository -Name PSGallery -ErrorAction Stop
        }
        if ($repository.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        }
    }

    foreach ($moduleName in $moduleNames) {
        $installedModule = Get-Module -ListAvailable -Name $moduleName |
            Where-Object { $_.ModuleBase -like "$(Join-Path $targetModulePath $moduleName)*" } |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $installedModule) {
            Write-Host "Installing $moduleName from PSGallery..." -ForegroundColor Cyan
            if (Get-Command Save-PSResource -ErrorAction SilentlyContinue) {
                if ($moduleName -eq 'HPCMSL') {
                    Save-PSResource -Name $moduleName -Repository PSGallery -Path $targetModulePath -TrustRepository -AcceptLicense -Quiet
                }
                else {
                    Save-PSResource -Name $moduleName -Repository PSGallery -Path $targetModulePath -TrustRepository -Quiet
                }
            }
            elseif ($moduleName -eq 'HPCMSL') {
                Save-Module -Name $moduleName -Repository PSGallery -Path $targetModulePath -Force -AcceptLicense -Confirm:$false
            }
            else {
                Save-Module -Name $moduleName -Repository PSGallery -Path $targetModulePath -Force -Confirm:$false
            }

            $installedModule = Get-Module -ListAvailable -Name $moduleName |
                Where-Object { $_.ModuleBase -like "$(Join-Path $targetModulePath $moduleName)*" } |
                Sort-Object Version -Descending |
                Select-Object -First 1
        }

        if (-not $installedModule) {
            throw "$moduleName was not found in $targetModulePath after installation."
        }

        Import-Module -Name $installedModule.Path -Force -ErrorAction Stop
        $loadedModule = Get-Module -Name $moduleName
        if (-not $loadedModule) {
            throw "$moduleName was installed but could not be loaded."
        }

        Write-Host "$moduleName $($loadedModule.Version) loaded successfully in PowerShell $($PSVersionTable.PSVersion)." -ForegroundColor Green
    }

    exit 0
}
catch {
    Write-Error "Failed to install or load required HP modules in PowerShell 7. $($_.Exception.Message)"
    exit 1
}
'@

$childScriptPath = Join-Path 'C:\Windows\Temp' ("Install-HPCMSL-PS7-{0}.ps1" -f [guid]::NewGuid())
try {
    Set-Content -Path $childScriptPath -Value $ps7Script -Encoding UTF8 -Force
    Write-Host "Handing HP module installation to PowerShell 7: $pwshPath" -ForegroundColor Cyan
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