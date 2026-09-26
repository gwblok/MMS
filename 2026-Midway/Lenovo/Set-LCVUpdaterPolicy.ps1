<#
.SYNOPSIS
    Configures Lenovo Commercial Vantage System Update policies.

.DESCRIPTION
    This ConfigMgr-friendly script writes the manually selected System Update
    filters and company settings to the Commercial Vantage policy registry key.
    Edit the settings near the top of the script before running it.

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
$CompanyName = 'Your Friendly Lenovo Team'
$SystemUpdateRepository = ''
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

function Set-LenovoVantageSU {
    [CmdletBinding()]
    param (

        [string]$CompanyName,
        [string]$SystemUpdateRepository,
        [ValidateSet('True','False')]
        [string]$ConfigureSystemUpdate = $true,

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
    if ($CompanyName) {
        New-ItemProperty -Path $RegistryPath -Name "CompanyName" -Value $CompanyName -PropertyType string -Force | Out-Null
    }
    if ($SystemUpdateRepository) {
        New-ItemProperty -Path $RegistryPath -Name "LocalRepository" -Value $SystemUpdateRepository -PropertyType string -Force | Out-Null
    }
    if ($ConfigureSystemUpdate) {
        if ($ConfigureSystemUpdate -eq $true){
            Write-Host "Setting SystemUpdateFilter to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
#ConfigureSystemUpdateUpdates
    #Region Critical
    if ($SUFilterCriticalAll) {
        if ($SUFilterCriticalAll -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.critical.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterCriticalApplication) {
        if ($SUFilterCriticalApplication -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalDriver) {
        if ($SUFilterCriticalDriver -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalBIOS) {
        if ($SUFilterCriticalBIOS -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalFirmware) {
        if ($SUFilterCriticalFirmware -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterCriticalOthers) {
        if ($SUFilterCriticalOthers -eq $true){
            Write-Host "Setting SystemUpdateFilter.critical.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.critical.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.critical.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion Critical
    #Region Recommended
    if ($SUFilterRecommendedAll) {
        if ($SUFilterRecommendedAll -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.recommended.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterRecommendedApplication) {
        if ($SUFilterRecommendedApplication -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedDriver) {
        if ($SUFilterRecommendedDriver -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedBIOS) {
        if ($SUFilterRecommendedBIOS -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedFirmware) {
        if ($SUFilterRecommendedFirmware -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterRecommendedOthers) {
        if ($SUFilterRecommendedOthers -eq $true){
            Write-Host "Setting SystemUpdateFilter.recommended.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.recommended.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.recommended.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion recommended
    #Region optional
    if ($SUFilterOptionalAll) {
        if ($SUFilterOptionalAll -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.application" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.driver" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.firmware" -Value 1 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.application" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.driver" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.firmware" -Value 0 -PropertyType dword -Force | Out-Null
            Write-Host "Setting SystemUpdateFilter.optional.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }    
    if ($SUFilterOptionalApplication) {
        if ($SUFilterOptionalApplication -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.application to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.application" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.application to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.application" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalDriver) {
        if ($SUFilterOptionalDriver -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.driver to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.driver" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.driver to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.driver" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalBIOS) {
        if ($SUFilterOptionalBIOS -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.BIOS to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.BIOS" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.BIOS to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.BIOS" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalFirmware) {
        if ($SUFilterOptionalFirmware -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.firmware to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.firmware" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.firmware to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.firmware" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($SUFilterOptionalOthers) {
        if ($SUFilterOptionalOthers -eq $true){
            Write-Host "Setting SystemUpdateFilter.optional.others to 1"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.others" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting SystemUpdateFilter.optional.others to 0"
            New-ItemProperty -Path $RegistryPath -Name "SystemUpdateFilter.optional.others" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    #EndRegion optional
}


#Feed Variables into Function
Set-LenovoVantageSU -CompanyName $CompanyName `
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