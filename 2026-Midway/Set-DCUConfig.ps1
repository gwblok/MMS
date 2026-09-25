<#
.SYNOPSIS
    Configures Dell Command | Update using hard-coded settings.
    Modify the variables area to fit your environment.

.DESCRIPTION
    Native PowerShell configuration script for Dell Command | Update. The
    settings below are passed to Set-DCUSettings from the OEMWrapPS module.
    Edit the values in the configuration section before running.

.NOTES
    Run as Administrator or in the ConfigMgr SYSTEM context on a Dell device.
    Set-DCUSettings configures the DCU registry/CLI settings and does not
    install or apply updates.
#>

$ErrorActionPreference = 'Stop'

### - Variables Section - ###
#region Variables Section
# Configuration: edit these values before deployment.
$AutoSuspendBitLocker = 'Enable'
$ScheduleAction = 'DownloadInstallAndNotify'
$ScheduleAuto = $true

$InstallationDeferral = 'Enable'
$DeferralInstallInterval = 3
$DeferralInstallCount = 5

$SystemRestartDeferral = 'Enable'
$DeferralRestartInterval = 3
$DeferralRestartCount = 5

$CustomCatalogPath = ''
$delayDays = 14
$Schedule = 'scheduleDaily'
$ScheduleDaily = '12:30'
$ScheduleWeekly = 'Wed'
$ScheduleMonthly = 'third'

$UpdateDeviceCategoryFilter = 'Disable'  # If set to Disable, the other device category settings will be ignored.
$UpdateDeviceCategoryAudio = 'True'
$UpdateDeviceCategoryVideo = 'True'
$UpdateDeviceCategoryNetwork = 'True'
$UpdateDeviceCategoryStorage = 'False'
$UpdateDeviceCategoryInput = 'False'
$UpdateDeviceCategoryChipset = 'True'
$UpdateDeviceCategoryOthers = 'False'

$UpdateSeverityFilter = 'Disable'  # If set to Disable, the other severity settings will be ignored.
$UpdateSeveritySecurity = 'True'
$UpdateSeverityCritical = 'True'
$UpdateSeverityRecommended = 'False'
$UpdateSeverityOptional = 'False'

$UpdateTypeFilter = 'Enable'  # If set to Disable, the other update type settings will be ignored.
$UpdateTypeBIOS = 'True'
$UpdateTypeFirmware = 'True'
$UpdateTypeDriver = 'True'
$UpdateTypeApplication = 'False'
$UpdateTypeOthers = 'False'
$UpdateTypeUtility = 'False'



#endregion Variables Section
### - End of Variables Section - ###  Please don't change below this. :-)

$moduleName = 'OEMWrapPS'
$minimumModuleVersion = [version]'1.0.11'
$UpdateDeviceCategories = @(
    if ($UpdateDeviceCategoryAudio -eq 'True') { 'audio' }
    if ($UpdateDeviceCategoryVideo -eq 'True') { 'video' }
    if ($UpdateDeviceCategoryNetwork -eq 'True') { 'network' }
    if ($UpdateDeviceCategoryStorage -eq 'True') { 'storage' }
    if ($UpdateDeviceCategoryInput -eq 'True') { 'input' }
    if ($UpdateDeviceCategoryChipset -eq 'True') { 'chipset' }
    if ($UpdateDeviceCategoryOthers -eq 'True') { 'others' }
)
$UpdateSeverities = @(
    if ($UpdateSeveritySecurity -eq 'True') { 'security' }
    if ($UpdateSeverityCritical -eq 'True') { 'critical' }
    if ($UpdateSeverityRecommended -eq 'True') { 'recommended' }
    if ($UpdateSeverityOptional -eq 'True') { 'optional' }
)
$UpdateTypes = @(
    if ($UpdateTypeBIOS -eq 'True') { 'bios' }
    if ($UpdateTypeFirmware -eq 'True') { 'firmware' }
    if ($UpdateTypeDriver -eq 'True') { 'driver' }
    if ($UpdateTypeApplication -eq 'True') { 'application' }
    if ($UpdateTypeOthers -eq 'True') { 'others' }
    if ($UpdateTypeUtility -eq 'True') { 'utility' }
)

try {
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).Manufacturer
    if ($manufacturer -notmatch 'Dell') {
        Write-Host "This script is designed for Dell systems. Detected manufacturer: $manufacturer" -ForegroundColor Yellow
        exit 0
    }

    $installedModule = Get-Module -ListAvailable -Name $moduleName |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $installedModule -or $installedModule.Version -lt $minimumModuleVersion) {
        Write-Host "Installing or updating $moduleName to version $minimumModuleVersion or newer..." -ForegroundColor Cyan
        $nugetProvider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if (-not $nugetProvider -or $nugetProvider.Version -lt [version]'2.8.5.201') {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -Confirm:$false -ErrorAction Stop | Out-Null
        }
        Import-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name $moduleName -Repository PSGallery -Scope AllUsers -MinimumVersion $minimumModuleVersion -Force -AllowClobber -Confirm:$false -ErrorAction Stop
    }

    Import-Module -Name $moduleName -Force -ErrorAction Stop
    $loadedModule = Get-Module -Name $moduleName -ErrorAction Stop
    $setDcuSettings = Get-Command Set-DCUSettings -ErrorAction SilentlyContinue
    if (-not $setDcuSettings) {
        throw 'Set-DCUSettings was not found after importing OEMWrapPS.'
    }
    if (-not $setDcuSettings.Parameters.ContainsKey('Schedule')) {
        throw "OEMWrapPS $minimumModuleVersion or newer is required because Set-DCUSettings does not expose the Schedule parameter."
    }

    Write-Host 'Applying Dell Command | Update configuration...' -ForegroundColor Cyan
    Write-Host "Schedule action: $ScheduleAction"
    Write-Host "Automatic schedule: $ScheduleAuto"
    Write-Host "Installation deferral: $InstallationDeferral ($DeferralInstallInterval days / $DeferralInstallCount deferrals)"
    Write-Host "Restart deferral: $SystemRestartDeferral ($DeferralRestartInterval days / $DeferralRestartCount deferrals)"
    Write-Host "Exclude updates newer than: $delayDays days"

    $settingsParameters = @{
        AutoSuspendBitLocker = $AutoSuspendBitLocker
        ScheduleAction = $ScheduleAction
        InstallationDeferral = $InstallationDeferral
        DeferralInstallInterval = $DeferralInstallInterval
        DeferralInstallCount = $DeferralInstallCount
        SystemRestartDeferral = $SystemRestartDeferral
        DeferralRestartInterval = $DeferralRestartInterval
        DeferralRestartCount = $DeferralRestartCount
        ExcludeUpdatesFromLastNDays = $delayDays
        Schedule = $Schedule
        ScheduleDaily = $ScheduleDaily
        ScheduleWeekly = $ScheduleWeekly
        ScheduleMonthly = $ScheduleMonthly
        UpdateDeviceCategoryFilter = $UpdateDeviceCategoryFilter
        UpdateDeviceCategories = $UpdateDeviceCategories
        UpdateSeverityFilter = $UpdateSeverityFilter
        UpdateSeverities = $UpdateSeverities
        UpdateTypeFilter = $UpdateTypeFilter
        UpdateTypes = $UpdateTypes
        Verbose = $true
    }

    if ($ScheduleAuto) {
        $settingsParameters.ScheduleAuto = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($CustomCatalogPath)) {
        $settingsParameters.CustomCatalogPath = $CustomCatalogPath
    }

    Set-DCUSettings @settingsParameters
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ' Dell Command | Update Configuration Summary' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host (" Module                  : {0} {1}" -f $moduleName, $loadedModule.Version) -ForegroundColor Gray
    Write-Host (" BitLocker suspension    : {0}" -f $AutoSuspendBitLocker) -ForegroundColor Gray
    Write-Host (" Schedule action         : {0}" -f $ScheduleAction) -ForegroundColor Gray
    Write-Host (" Automatic schedule      : {0}" -f $ScheduleAuto) -ForegroundColor Gray
    Write-Host (" Schedule                : {0}" -f $Schedule) -ForegroundColor Gray
    Write-Host (" Schedule details        : Daily={0}; Weekly={1}; Monthly={2}" -f $ScheduleDaily, $ScheduleWeekly, $ScheduleMonthly) -ForegroundColor Gray
    Write-Host (" Installation deferral  : {0} (Interval={1}; Count={2})" -f $InstallationDeferral, $DeferralInstallInterval, $DeferralInstallCount) -ForegroundColor Gray
    Write-Host (" Restart deferral       : {0} (Interval={1}; Count={2})" -f $SystemRestartDeferral, $DeferralRestartInterval, $DeferralRestartCount) -ForegroundColor Gray
    Write-Host (" Delay days             : {0}" -f $delayDays) -ForegroundColor Gray
    Write-Host (" Device category filter : {0} ({1})" -f $UpdateDeviceCategoryFilter, ($UpdateDeviceCategories -join ', ')) -ForegroundColor Gray
    Write-Host (" Severity filter        : {0} ({1})" -f $UpdateSeverityFilter, ($UpdateSeverities -join ', ')) -ForegroundColor Gray
    Write-Host (" Update type filter     : {0} ({1})" -f $UpdateTypeFilter, ($UpdateTypes -join ', ')) -ForegroundColor Gray
    Write-Host (" Custom catalog         : {0}" -f $(if ($CustomCatalogPath) { $CustomCatalogPath } else { 'Default Dell catalog' })) -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ' Configuration completed successfully.' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor DarkCyan
    exit 0
}
catch {
    Write-Error "Failed to configure Dell Command | Update. $($_.Exception.Message)"
    exit 1
}
