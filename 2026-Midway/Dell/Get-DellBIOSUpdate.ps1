#Connects to TS Environment and Creates (confirms) Registry Stucture in place for the Win10 Upgrade Build.
try {
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    Write-Host "Connected to TS Environment." -ForegroundColor Green
}
catch {
    Write-Host "Not connected to TS Environment." -ForegroundColor yellow
}

Import-Module OEMWrapPS

# Set this value when the Dell BIOS has an administrator password configured.
if ($TSENV) {
    $BIOSPassword = $tsenv.Value('BIOSPassword')
}

$UpdateCheck = Get-DellBIOSUpdates -Details


If ($UpdateCheck.BIOSIsCurrent){
    Write-Host "No Dell BIOS update is available." -ForegroundColor Yellow


}
else {
    Write-Host "A Dell BIOS update is available." -ForegroundColor Green
    if ((Test-DellBIOSPassword) -and [string]::IsNullOrWhiteSpace($BIOSPassword)) {
        Write-Host "A Dell BIOS password is configured, but no password was provided. BIOS update was not attempted." -ForegroundColor Red
        return
    }

    if ([string]::IsNullOrWhiteSpace($BIOSPassword)) {
        Get-DellBIOSUpdates -Flash
        if ($TSENV) {
            $tsenv.Value('BIOSRebootRequired') = $true
        }
    }
    else {
        Get-DellBIOSUpdates -Flash -Password $BIOSPassword
        if ($TSENV) {
            $tsenv.Value('BIOSRebootRequired') = $true
        }
    }
}