if ($env:SystemDrive -eq "X:"){
    Write-Host "Running in WinPE, this step requires a full Windows environment to run properly."
    exit 0
}
$MakeAlias = 'Lenovo'
$ModelAlias = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).Model

# ConfigMgr values. Change these values to adjust Commercial Vantage policy settings.
$WarrantyInfoHide = $false
$MyDevicePageHide = $false
$WiFiSecurityPageHide = $false
$HardwareScanPageHide = $false
$GiveFeedbackPageHide = $true
$TurnOffMicrophoneSettings = $true

Write-Host "==================================================================="
write-host "Installing LCV on  $MakeAlias $ModelAlias Devices"
write-host "Reporting Variables:"
write-host "WarrantyInfoHide: $WarrantyInfoHide"
write-host "MyDevicePageHide: $MyDevicePageHide" 
write-host "WiFiSecurityPageHide: $WiFiSecurityPageHide"
write-host "HardwareScanPageHide: $HardwareScanPageHide"
write-host "GiveFeedbackPageHide: $GiveFeedbackPageHide"
write-host "TurnOffMicrophoneSettings: $TurnOffMicrophoneSettings"


#region Functions
function Get-DownloadFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $destinationDirectory = Split-Path -Path $Destination -Parent
    if (-not (Test-Path -Path $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    try {
        Write-Host "Downloading with BITS: $Uri" -ForegroundColor Cyan
        Start-BitsTransfer -Source $Uri -Destination $Destination -ErrorAction Stop
    }
    catch {
        Write-Host "BITS download failed for $Uri. Falling back to Invoke-WebRequest." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing -ErrorAction Stop
        }
        catch {
            throw "Download failed for '$Uri'. $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path -Path $Destination)) {
        throw "Download completed without creating '$Destination'."
    }

    return (Get-Item -Path $Destination)
}

function Install-LenovoVantage {
    [CmdletBinding()]
    param (
    [bool]$IncludeSUHelper = $true
    )
    # Define the URL and temporary file path - https://support.lenovo.com/us/en/solutions/hf003321-lenovo-vantage-for-enterprise
    #$url = "https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_10.2401.29.0.zip"
    
    #Jan 25 release - seems to be the best working version.
    #$url = "https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_10.2501.15.0_v3.zip"
    
    #July 2025 Release - having issues, fails to install during OSD
    #$url = 'https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_20.2506.39.0_v17.zip'
    #January 23, 2026 Release
    #$url = 'https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_20.2511.24.0.20251217075118.zip'
    $urlservice = 'https://filedownload.csw.lenovo.com/enm/vantage30/service/LenovoVantageServiceSetup.exe'

    #September 11 2025 Release
    $url = 'https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_20.2606.24.0.20260917014203.zip'

    #$tempFilePath = "C:\Windows\Temp\lenovo_vantage.zip"
    $tempExtractPath = "C:\Windows\Temp\LCV\Extract"
    $tempDownloadPath = "C:\Windows\Temp\LCV\Download"
    if (!(Test-Path -Path $tempDownloadPath)) {
        New-Item -ItemType Directory -Path $tempDownloadPath | Out-Null
    }
    if (!(Test-Path -Path $tempExtractPath)) {
        New-Item -ItemType Directory -Path $tempExtractPath | Out-Null
    }
    $ExpandFile = Join-Path -Path $tempDownloadPath -ChildPath 'LenovoCommercialVantage.zip'
    $null = Get-DownloadFile -Uri $URL -Destination $ExpandFile
    Write-Host "Downloaded Content to: $ExpandFile" -ForegroundColor Green

    #URL Service
    $ExpandFileService = Join-Path -Path $tempDownloadPath -ChildPath 'LenovoVantageServiceSetup.exe'
    $null = Get-DownloadFile -Uri $urlservice -Destination $ExpandFileService
    Write-Host "Downloaded Content to: $ExpandFileService" -ForegroundColor Green
    
    # Check if the transfer was successful
    if (Test-Path -Path $ExpandFile) {
        # Start the installation process
        Write-Host -ForegroundColor Green "Installation file downloaded successfully. Starting installation..."
        Write-Host -ForegroundColor Cyan " Extracting $ExpandFile to $tempExtractPath"
        if (test-path -path $tempExtractPath) {Remove-Item -Path $tempExtractPath -Recurse -Force}
        Expand-Archive -Path $ExpandFile -Destination $tempExtractPath 
        
    } else {
        Write-Host "Failed to download the file."
        return
    }

    #Lenovo Vantage Service
    #Write-Host -ForegroundColor Cyan " Installing Lenovo Vantage Service..."
    #Write-Host "Launching $tempExtractPath\VantageService\Install-VantageService.ps1"
    #Invoke-Expression -command "$tempExtractPath\VantageService\Install-VantageService.ps1"
    
    $installerPath = Join-Path -Path $tempExtractPath -ChildPath 'VantageInstaller.exe'
    Write-Host "Launching $installerPath Install -Vantage"
    $InstallProcess = Start-Process `
        -FilePath $installerPath `
        -ArgumentList 'Install', '-Vantage' `
        -Wait `
        -PassThru
    Write-Host "Vantage installer exited with code $($InstallProcess.ExitCode)"
    
    if (Test-Path -path $ExpandFileService) {
        Write-Host "Starting Install of: $ExpandFileService" -ForegroundColor Green
        $InstallProcess = Start-Process -FilePath $ExpandFileService -ArgumentList "/VERYSILENT /NORESTART" -Wait -PassThru
        $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
        New-Item -Path $RegistryPath -ItemType Directory -Force |Out-Null
        New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 1 -PropertyType dword -Force | Out-Null
        New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 1 -PropertyType dword -Force | Out-Null
    }

    <#  - These Scripts are no longer included in the Lenovo Vantage installer
    #Lenovo Vantage Batch File
    write-host -ForegroundColor Cyan " Installing Lenovo Vantage...batch file..."
    $ArgumentList = "/c $($tempExtractPath)\setup-commercial-vantage.bat"
    $InstallProcess = Start-Process -FilePath "cmd.exe" -ArgumentList $ArgumentList -Wait -PassThru
    if ($InstallProcess.ExitCode -eq 0) {
        Write-Host -ForegroundColor Green "Lenovo Vantage completed successfully."
        $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
        New-Item -Path $RegistryPath -ItemType Directory -Force |Out-Null
        New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 1 -PropertyType dword -Force | Out-Null
        New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 1 -PropertyType dword -Force | Out-Null
    } else {
        Write-Host -ForegroundColor Red "Lenovo Vantage failed with exit code $($InstallProcess.ExitCode)."
    }
    
    Write-Host "Launching $tempExtractPath\lenovo-commercial-vantage-install.ps1"
    #Get Current Path
    $CurrentPath = Get-Location
    Set-Location -Path $tempExtractPath
    try {
        Invoke-Expression -command "$tempExtractPath\lenovo-commercial-vantage-install.ps1"
    }
    catch {
        Write-Host "Had issues with $($_.Exception.Message)"
    }
    
    Set-Location -Path $CurrentPath
    #>



    if ($IncludeSUHelper){
        $InstallProcess = Start-Process -FilePath $tempExtractPath\SystemUpdate\SUHelperSetup.exe -ArgumentList "/VERYSILENT /NORESTART" -Wait -PassThru
        if ($InstallProcess.ExitCode -eq 0) {
            Write-Host -ForegroundColor Green "Lenovo SU Helper completed successfully."
        } else {
            Write-Host -ForegroundColor Red "Lenovo SU Helper failed with exit code $($InstallProcess.ExitCode)."
        }
    }
}


function Set-LenovoVantage {
    [CmdletBinding()]
    param (
    [ValidateSet('True','False')]
    [string]$AcceptEULAAutomatically = 'True',
    [ValidateSet('True','False')]
    [string]$WarrantyInfoHide,
    [ValidateSet('True','False')]
    [string]$WarrantyWriteWMI = 'True',
    [ValidateSet('True','False')]
    [string]$MyDevicePageHide,
    [ValidateSet('True','False')]
    [string]$WiFiSecurityPageHide,
    [ValidateSet('True','False')]
    [string]$HardwareScanPageHide,
    [ValidateSet('True','False')]
    [string]$GiveFeedbackPageHide,
    [ValidateSet('True','False')]
    [string]$TurnOffMicrophoneSettings = 'True'    
    )
    
    
    $RegistryPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
    if (!(Test-Path -Path $RegistryPath)){
        return "Lenovo Vantage is not installed. Please install Lenovo Vantage first."
    }
    # Check if Lenovo Vantage is installed
    if (Test-Path "C:\Program Files (x86)\Lenovo\VantageService") {
        #Write-Host "Lenovo Vantage is already installed."
    } else {
        Write-Host "Lenovo Vantage is not installed. Installing..."
        Install-LenovoVantage
    }
    # Check if the registry path exists
    if (Test-Path $RegistryPath) {
        #Write-Host "Registry path already exists"
    } else {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    
    # Set the registry values
    if ($AcceptEULAAutomatically) {
        if ($AcceptEULAAutomatically -eq $true){
            Write-Host "Setting AcceptEULAAutomatically to 1"
            New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting AcceptEULAAutomatically to 0"
            New-ItemProperty -Path $RegistryPath -Name "AcceptEULAAutomatically" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    
    if ($WarrantyInfoHide) {
        if ($WarrantyInfoHide -eq $true){
            Write-Host "Setting WarrantyInfoHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "feature.warranty" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WarrantyInfoHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "feature.warranty" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($WarrantyWriteWMI) {
        if ($WarrantyWriteWMI -eq $true){
            Write-Host "Setting WarrantyWriteWMI to 1"
            New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WarrantyWriteWMI to 0"
            New-ItemProperty -Path $RegistryPath -Name "wmi.warranty" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    
    if ($MyDevicePageHide) {
        if ($MyDevicePageHide -eq $true){
            Write-Host "Setting MyDevicePageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.myDevice" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting MyDevicePageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.myDevice" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    
    if ($WiFiSecurityPageHide) {
        if ($WiFiSecurityPageHide -eq $true){
            Write-Host "Setting WiFiSecurityPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.wifiSecurity" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting WiFiSecurityPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.wifiSecurity" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    
    if ($HardwareScanPageHide) {
        if ($HardwareScanPageHide -eq $true){
            Write-Host "Setting HardwareScanPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "page.hardwareScan" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting HardwareScanPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "page.hardwareScan" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    
    if ($GiveFeedbackPageHide) {
        if ($GiveFeedbackPageHide -eq $true){
            Write-Host "Setting GiveFeedbackPageHide to 1"
            New-ItemProperty -Path $RegistryPath -Name "feature.giveFeedback" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting GiveFeedbackPageHide to 0"
            New-ItemProperty -Path $RegistryPath -Name "feature.giveFeedback" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }
    if ($TurnOffMicrophoneSettings) {
        if ($TurnOffMicrophoneSettings -eq $true){
            Write-Host "Setting TurnOffMicrophoneSettings to 1"
            New-ItemProperty -Path $RegistryPath -Name "feature.device-settings.audio.microphone-settings" -Value 1 -PropertyType dword -Force | Out-Null
        }
        else {
            Write-Host "Setting TurnOffMicrophoneSettings to 0"
            New-ItemProperty -Path $RegistryPath -Name "feature.device-settings.audio.microphone-settings" -Value 0 -PropertyType dword -Force | Out-Null
        }
    }   
}

#Endregion Functions

# Install Lenovo Vantage
Write-Host "Launching Install-LenovoVantage"
Install-LenovoVantage

# Set Lenovo Vantage Settings
Write-Host "Setting Lenovo Vantage Settings"

Set-LenovoVantage -AcceptEULAAutomatically $true `
-WarrantyInfoHide $WarrantyInfoHide `
-WarrantyWriteWMI $true `
-MyDevicePageHide $MyDevicePageHide `
-WiFiSecurityPageHide $WiFiSecurityPageHide `
-HardwareScanPageHide $HardwareScanPageHide `
-GiveFeedbackPageHide $GiveFeedbackPageHide


