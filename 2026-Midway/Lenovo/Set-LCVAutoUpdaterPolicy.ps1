<#
.SYNOPSIS
    Configures Lenovo Commercial Vantage automatic update policies.

.DESCRIPTION
    This ConfigMgr-friendly script writes the manually selected automatic update
    schedule, deferral, filter, and company settings to the Commercial Vantage
    policy registry key. Edit the settings near the top of the script before
    running it.

.REQUIREMENTS
    Run in full Windows as Administrator or in the ConfigMgr SYSTEM context.
    Lenovo Commercial Vantage must already be installed.

.DOCUMENTATION
    Lenovo Commercial Vantage configuration guide:
    https://docs.lenovocdrt.com/guides/lcv/configuration/

.NOTES
    Lenovo may add new Commercial Vantage settings over time. If you find a
    setting that is documented by Lenovo but is not represented here, please
    reach out or submit a pull request so it can be added.
#>

if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}
# ConfigMgr/manual settings. Edit these values before running the script.
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage'
$AutoUpdatesEnabled = $true
$CompanyName = 'Your Friendly Lenovo Team'
$SystemUpdateRepository = ''
$ScheduleTimeAutoUpdate = '18:30:00'
$UpdateDeferrals = 'Enabled'
$DeferLimit = 25
$DeferTime = 60
$SUUpdateFrequencyWeekFirst = $true
$SUUpdateFrequencyWeekSecond = $false
$SUUpdateFrequencyWeekThird = $false
$SUUpdateFrequencyWeekFourth = $false
$SUUpdateFrequencyWeekLast = $false
$SUUpdateFrequencyDayMonday = $false
$SUUpdateFrequencyDayTuesday = $false
$SUUpdateFrequencyDayWednesday = $true
$SUUpdateFrequencyDayThursday = $false
$SUUpdateFrequencyDayFriday = $false
$SUUpdateFrequencyDaySaturday = $false
$SUUpdateFrequencyDaySunday = $false
$SUFilterCriticalApplication = 'True'
$SUFilterCriticalDriver = 'True'
$SUFilterCriticalBIOS = 'True'
$SUFilterCriticalFirmware = 'True'
$SUFilterCriticalOthers = 'True'
$SUFilterRecommendedApplication = 'True'
$SUFilterRecommendedDriver = 'True'
$SUFilterRecommendedBIOS = 'True'
$SUFilterRecommendedFirmware = 'True'
$SUFilterRecommendedOthers = 'True'
$SUFilterOptionalApplication = 'False'
$SUFilterOptionalDriver = 'False'
$SUFilterOptionalBIOS = 'False'
$SUFilterOptionalFirmware = 'False'
$SUFilterOptionalOthers = 'False'

if (-not $AutoUpdatesEnabled) {
    Write-Host 'AutoUpdatesEnabled is set to false. Skipping auto-update configuration.'
    New-ItemProperty -Path $RegistryPath -Name 'AutoUpdateEnabled' -Value 0 -PropertyType dword -Force | Out-Null
    exit 0
}

if (!(Test-Path -Path $RegistryPath)){
    return "Lenovo Vantage is not installed. Please install Lenovo Vantage first."
}

if ($SUUpdateFrequencyWeekFirst -eq $false -and $SUUpdateFrequencyWeekSecond -eq $false -and $SUUpdateFrequencyWeekThird -eq $false -and $SUUpdateFrequencyWeekFourth -eq $false -and $SUUpdateFrequencyWeekLast -eq $false) {
    Write-Host "Setting SUUpdateFrequency to default of 1st week of the month, as all weeks were set to false"
    $SUUpdateFrequencyWeekFirst = $true
}
if ($SUUpdateFrequencyDayMonday -eq $false -and $SUUpdateFrequencyDayTuesday -eq $false -and $SUUpdateFrequencyDayWednesday -eq $false -and $SUUpdateFrequencyDayThursday -eq $false -and $SUUpdateFrequencyDayFriday -eq $false -and $SUUpdateFrequencyDaySaturday -eq $false -and $SUUpdateFrequencyDaySunday -eq $false) {
    Write-Host "Setting SUUpdateFrequency to default of Wednesday, as all days were set to false"
    $SUUpdateFrequencyDayWednesday = $true
}


function Set-LenovoVantageAutoUpdates {
    [CmdletBinding()]
    param (

        [string]$CompanyName,
        [string]$SystemUpdateRepository,
        [ValidateSet('True','False')]
        [string]$AutoUpdateEnabled = $true,
        [ValidateSet('True','False')]
        [string]$ConfigureAutoUpdate = $true,
        [Parameter(HelpMessage="Format HH:mm:ss For example 18:30:00 for 6:30PM")]
        [ValidatePattern("[0-9][0-9]:[0-9][0-9]:[0-9][0-9]")]
        [string]$ScheduleTimeAutoUpdate = "18:30:00", #6:30PM by Default

        
        #Update Deferrals
        [ValidateSet('Enabled','Disabled')]
        [string]$UpdateDeferrals = "Enabled",
        [Parameter(HelpMessage="number of times the end-user is allowed to defer updates (DeferLimit)")]
        [ValidateRange(0,100)]
        [string]$DeferLimit = 10, #10 times by Default
        [Parameter(HelpMessage="amount of time for each deferral (DeferTime)")]
        [ValidateRange(0,60)]
        [string]$DeferTime = 60, #60 minutes by Default


        #ConfigureSystemUpdateUpdates
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalAll,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalDriver,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterCriticalOthers,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedAll,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedDriver,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterRecommendedOthers,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalAll,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalApplication,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalDriver,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalBIOS,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalFirmware,
        [ValidateSet('True','False')]
        [string]$SUFilterOptionalOthers
    )

    $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
    if (!(Test-Path -Path $RegistryPath)){
        return "Lenovo Vantage is not installed. Please install Lenovo Vantage first."
    }
    #Enabling Dependencies
    if ($ScheduleTimeAutoUpdate){$AutoUpdateEnabled = $true}
    if ($DeferLimit) {$UpdateDeferrals = "Enabled"}
    if ($DeferTime)  {$UpdateDeferrals = "Enabled"}
    if ($UpdateDeferrals){$AutoUpdateEnabled = $true}
    if ($AutoUpdateEnabled) {$ConfigureAutoUpdate = $true}

    #Start Doing Stuff
    if ($CompanyName) {
        New-ItemProperty -Path $RegistryPath -Name "CompanyName" -Value $CompanyName -PropertyType string -Force | Out-Null
    }
    if ($SystemUpdateRepository) {
        New-ItemProperty -Path $RegistryPath -Name "LocalRepository" -Value $SystemUpdateRepository -PropertyType string -Force | Out-Null
    }
    if ($AutoUpdateEnabled) {
        if ($AutoUpdateEnabled -eq $true){
            Write-Host "Setting AutoUpdateEnabled to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoUpdateEnabled" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoUpdateEnabled to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoUpdateEnabled" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($ConfigureAutoUpdate) {
        if ($ConfigureAutoUpdate -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($ScheduleTimeAutoUpdate) {
        Write-Host "Setting AutoUpdateScheduleTime to $ScheduleTimeAutoUpdate"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateScheduleTime" -Value $ScheduleTimeAutoUpdate -PropertyType string -Force | Out-Null
    }
    
    #Deferrals

    if ($UpdateDeferrals) {
        if ($UpdateDeferrals -eq "Enabled"){
            Write-Host "Setting DeferUpdateEnabled to 1"
            New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled" -Value 1 -PropertyType dword -Force | Out-Null

            if ($DeferLimit) {
                Write-Host "Setting DeferUpdateEnabled.Limit to $DeferLimit"
                New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Limit" -Value $DeferLimit -PropertyType string -Force | Out-Null
            }
            else {
                Write-Host "Setting DeferUpdateEnabled.Limit to Default"
                New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Limit" -Value "" -PropertyType string -Force | Out-Null 
            }
            if ($DeferTime) {
                Write-Host "Setting DeferUpdateEnabled.Time to $DeferTime"
                New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Time" -Value $DeferTime -PropertyType string -Force | Out-Null
            }
            else {
                Write-Host "Setting DeferUpdateEnabled.Time to Default of 60"
                New-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Time" -Value "60" -PropertyType string -Force | Out-Null
            }
        }
        elseif ($UpdateDeferrals -eq "Disabled") {
            Write-Host "Removing Update Deferral Properties"
            Remove-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled" -Force | Out-Null
            Remove-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Time" -Force | Out-Null
            Remove-ItemProperty -Path $RegistryPath -Name "DeferUpdateEnabled.Limit" -Force | Out-Null

        }
    }

    
#ConfigureSystemUpdateUpdates
    #Region Critical
    if ($SUFilterCriticalAll) {
        if ($SUFilterCriticalAll -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.critical.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterCriticalApplication) {
        if ($SUFilterCriticalApplication -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalDriver) {
        if ($SUFilterCriticalDriver -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalBIOS) {
        if ($SUFilterCriticalBIOS -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalFirmware) {
        if ($SUFilterCriticalFirmware -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalOthers) {
        if ($SUFilterCriticalOthers -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.critical.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.critical.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.critical.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion Critical
    #Region Recommended
    if ($SUFilterRecommendedAll) {
        if ($SUFilterRecommendedAll -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.recommended.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterRecommendedApplication) {
        if ($SUFilterRecommendedApplication -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedDriver) {
        if ($SUFilterRecommendedDriver -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedBIOS) {
        if ($SUFilterRecommendedBIOS -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedFirmware) {
        if ($SUFilterRecommendedFirmware -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedOthers) {
        if ($SUFilterRecommendedOthers -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.recommended.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.recommended.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.recommended.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion recommended
    #Region optional
    if ($SUFilterOptionalAll) {
        if ($SUFilterOptionalAll -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting AutoSystemUpdateFilter.optional.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterOptionalApplication) {
        if ($SUFilterOptionalApplication -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalDriver) {
        if ($SUFilterOptionalDriver -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalBIOS) {
        if ($SUFilterOptionalBIOS -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalFirmware) {
        if ($SUFilterOptionalFirmware -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalOthers) {
        if ($SUFilterOptionalOthers -eq $true){
            Write-Host "Setting AutoSystemUpdateFilter.optional.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AutoSystemUpdateFilter.optional.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "AutoSystemUpdateFilter.optional.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion optional
}

#Write Host All Variables
Write-Host "CompanyName: $CompanyName"
Write-Host "SystemUpdateRepository: $SystemUpdateRepository" 
Write-Host "AutoUpdateEnabled: $AutoUpdateEnabled"
Write-Host "ConfigureAutoUpdate: $ConfigureAutoUpdate"
Write-Host "ScheduleTimeAutoUpdate: $ScheduleTimeAutoUpdate"
Write-Host "UpdateDeferrals: $UpdateDeferrals" 
Write-Host "DeferLimit: $DeferLimit"
Write-Host "DeferTime: $DeferTime"
Write-Host "SUFilterCriticalApplication: $SUFilterCriticalApplication"
Write-Host "SUFilterCriticalDriver: $SUFilterCriticalDriver"
Write-Host "SUFilterCriticalBIOS: $SUFilterCriticalBIOS"
Write-Host "SUFilterCriticalFirmware: $SUFilterCriticalFirmware"
Write-Host "SUFilterCriticalOthers: $SUFilterCriticalOthers"
Write-Host "SUFilterRecommendedApplication: $SUFilterRecommendedApplication"
Write-Host "SUFilterRecommendedDriver: $SUFilterRecommendedDriver"
Write-Host "SUFilterRecommendedBIOS: $SUFilterRecommendedBIOS"
Write-Host "SUFilterRecommendedFirmware: $SUFilterRecommendedFirmware"
Write-Host "SUFilterRecommendedOthers: $SUFilterRecommendedOthers"
Write-Host "SUFilterOptionalApplication: $SUFilterOptionalApplication"
Write-Host "SUFilterOptionalDriver: $SUFilterOptionalDriver"
Write-Host "SUFilterOptionalBIOS: $SUFilterOptionalBIOS"
Write-Host "SUFilterOptionalFirmware: $SUFilterOptionalFirmware"
Write-Host "SUFilterOptionalOthers: $SUFilterOptionalOthers"


#Feed Variables into Function
Set-LenovoVantageAutoUpdates -CompanyName $CompanyName `
    -SystemUpdateRepository $SystemUpdateRepository `
    -AutoUpdateEnabled $true `
    -ConfigureAutoUpdate $true `
    -ScheduleTimeAutoUpdate $ScheduleTimeAutoUpdate `
    -UpdateDeferrals $UpdateDeferrals `
    -DeferLimit $DeferLimit `
    -DeferTime $DeferTime `
    -SUFilterCriticalApplication $SUFilterCriticalApplication `
    -SUFilterCriticalDriver $SUFilterCriticalDriver `
    -SUFilterCriticalBIOS $SUFilterCriticalBIOS `
    -SUFilterCriticalFirmware $SUFilterCriticalFirmware `
    -SUFilterCriticalOthers $SUFilterCriticalOthers `
    -SUFilterRecommendedApplication $SUFilterRecommendedApplication `
    -SUFilterRecommendedDriver $SUFilterRecommendedDriver `
    -SUFilterRecommendedBIOS $SUFilterRecommendedBIOS `
    -SUFilterRecommendedFirmware $SUFilterRecommendedFirmware `
    -SUFilterRecommendedOthers $SUFilterRecommendedOthers `
    -SUFilterOptionalApplication $SUFilterOptionalApplication `
    -SUFilterOptionalDriver $SUFilterOptionalDriver `
    -SUFilterOptionalBIOS $SUFilterOptionalBIOS `
    -SUFilterOptionalFirmware $SUFilterOptionalFirmware `
    -SUFilterOptionalOthers $SUFilterOptionalOthers

#These are extra variables that are used in the Task Sequence but not in the function

#Setting Updates to run each month by Default:
Write-Host "Setting AutoUpdateMonthlySchedule.month.AllMonths to 1"
New-ItemProperty -Path $RegistryPath -Name "AutoUpdateMonthlySchedule.month.AllMonths" -Value 1 -PropertyType dword -Force | Out-Null

#Which weeks of the month to run updates
if ($SUUpdateFrequencyWeekFirst) {
    if ($SUUpdateFrequencyWeekFirst -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.frequency.FirstWeek to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.FirstWeek" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.frequency.FirstWeek to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.FirstWeek" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyWeekSecond) {
    if ($SUUpdateFrequencyWeekSecond -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.frequency.SecondWeek to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.SecondWeek" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.frequency.SecondWeek to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.SecondWeek" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyWeekThird) {
    if ($SUUpdateFrequencyWeekThird -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.frequency.ThirdWeek to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.ThirdWeek" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.frequency.ThirdWeek to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.ThirdWeek" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyWeekFourth) {
    if ($SUUpdateFrequencyWeekFourth -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.frequency.FourthWeek to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.FourthWeek" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.frequency.FourthWeek to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.FourthWeek" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyWeekLast) {
    if ($SUUpdateFrequencyWeekLast -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.frequency.LastWeek to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.LastWeek" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.frequency.LastWeek to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.frequency.LastWeek" -Value 0 -PropertyType dword -Force | Out-Null
    }
}

#Which days of the week to run updates
if ($SUUpdateFrequencyDayMonday) {
    if ($SUUpdateFrequencyDayMonday -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Monday to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Monday" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Monday to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Monday" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyDayTuesday) {
    if ($SUUpdateFrequencyDayTuesday -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Tuesday to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Tuesday" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Tuesday to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Tuesday" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyDayWednesday) {
    if ($SUUpdateFrequencyDayWednesday -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Wednesday to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Wednesday" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Wednesday to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Wednesday" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyDayThursday) {
    if ($SUUpdateFrequencyDayThursday -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Thursday to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Thursday" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Thursday to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Thursday" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyDayFriday) {
    if ($SUUpdateFrequencyDayFriday -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Friday to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Friday" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Friday to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Friday" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyDaySaturday) {
    if ($SUUpdateFrequencyDaySaturday -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Saturday to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Saturday" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Saturday to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Saturday" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
if ($SUUpdateFrequencyDaySunday) {
    if ($SUUpdateFrequencyDaySunday -eq $true){
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Sunday to 1"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Sunday" -Value 1 -PropertyType dword -Force | Out-Null
    }
    else {
        Write-Host "Setting AutoUpdateDailySchedule.dayOfWeek.Sunday to 0"
        New-ItemProperty -Path $RegistryPath -Name "AutoUpdateDailySchedule.dayOfWeek.Sunday" -Value 0 -PropertyType dword -Force | Out-Null
    }
}
#End of Task Sequence Variables