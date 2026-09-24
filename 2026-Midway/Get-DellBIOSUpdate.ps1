Import-Module OEMWrapPS

# Set this value when the Dell BIOS has an administrator password configured.
$BIOSPassword = ''

$UpdateCheck = Get-DellBIOSUpdates -Check

If ($UpdateCheck){
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
    }
    else {
        Get-DellBIOSUpdates -Flash -Password $BIOSPassword
    }
}