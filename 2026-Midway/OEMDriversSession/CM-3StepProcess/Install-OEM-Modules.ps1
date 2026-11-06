<#
.SYNOPSIS
    Installs the appropriate OEM PowerShell module for the current computer.

.DESCRIPTION
    Detects the computer manufacturer and installs the matching module from
    PSGallery into the Windows PowerShell 5.1 module path:

    Panasonic - PanasonicCommandUpdate
    HP        - HPCMSL and OEMWrapPS
    Lenovo    - Lenovo.Client.Update
    Dell      - OEMWrapPS

    The script can be called from Windows PowerShell 5.1. PowerShell 7 performs
    the Gallery download, then the module is imported from the PS5-compatible
    module path.

.NOTES
    Run as Administrator or ConfigMgr SYSTEM when using AllUsers installation.
#>

$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
$manufacturer = $computerSystem.Manufacturer

$moduleNames = switch -Regex ($manufacturer) {
    'Panasonic' { @('PanasonicCommandUpdate'); break }
    'HP|Hewlett-Packard' { @('HPCMSL', 'OEMWrapPS'); break }
    'Lenovo' { @('Lenovo.Client.Update'); break }
    'Dell' { @('OEMWrapPS'); break }
    default { @() }
}

if ($moduleNames.Count -eq 0) {
    Write-Error "Unsupported computer manufacturer: $manufacturer"
    exit 1
}

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

$moduleNamesValue = $moduleNames -join ','
$ps7Script = @'
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$moduleNames = '__MODULE_NAMES__' -split ','
$manufacturer = '__MANUFACTURER__'
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
            Set-PSResourceRepository -Name PSGallery -Trusted
        }

    }
    else {
        Import-Module PackageManagement -ErrorAction Stop
        Import-Module PowerShellGet -ErrorAction Stop
        $gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if (-not $gallery) {
            Register-PSRepository -Default -ErrorAction Stop
            $gallery = Get-PSRepository -Name PSGallery -ErrorAction Stop
        }
        if ($gallery.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        }

    }

    foreach ($moduleName in $moduleNames) {
        $acceptLicense = $moduleName -eq 'HPCMSL'
        $installedModule = Get-Module -ListAvailable -Name $moduleName |
            Where-Object { $_.ModuleBase -like "$(Join-Path $targetModulePath $moduleName)*" } |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $installedModule) {
            Write-Host "Installing $moduleName from PSGallery..." -ForegroundColor Cyan
            if (Get-Command Save-PSResource -ErrorAction SilentlyContinue) {
                if ($acceptLicense) {
                    Save-PSResource -Name $moduleName -Repository PSGallery -Path $targetModulePath -TrustRepository -AcceptLicense -Quiet
                }
                else {
                    Save-PSResource -Name $moduleName -Repository PSGallery -Path $targetModulePath -TrustRepository -Quiet
                }
            }
            elseif ($acceptLicense) {
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

        Import-Module -Name $installedModule.Path -Force
        $loadedModule = Get-Module -Name $moduleName
        if (-not $loadedModule) {
            throw "$moduleName was installed but could not be loaded."
        }

        Write-Host "$moduleName $($loadedModule.Version) loaded successfully for $manufacturer." -ForegroundColor Green
    }
    exit 0
}
catch {
    Write-Error "Failed to install or load required module(s) for $manufacturer. $($_.Exception.Message)"
    exit 1
}
'@
$ps7Script = $ps7Script.Replace('__MODULE_NAMES__', $moduleNamesValue)
$ps7Script = $ps7Script.Replace('__MANUFACTURER__', $manufacturer)

$childScriptPath = Join-Path 'C:\Windows\Temp' ("Install-OEMByManufacturer-PS7-{0}.ps1" -f [guid]::NewGuid())
try {
    Set-Content -Path $childScriptPath -Value $ps7Script -Encoding UTF8 -Force
    Write-Host "Detected manufacturer: $manufacturer" -ForegroundColor Cyan
    Write-Host "Selected modules: $($moduleNames -join ', ')" -ForegroundColor Cyan
    Write-Host "Handing installation to PowerShell 7: $pwshPath" -ForegroundColor Cyan
    & $pwshPath -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $childScriptPath
    $exitCode = $LASTEXITCODE
}
finally {
    try {
        Remove-Item -LiteralPath $childScriptPath -Force -ErrorAction Stop
    }
    catch {
        # Cleanup failure must not mask the installation result.
    }
}

exit $exitCode
