function Save-BootstrapPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.ServerCertificateValidationCallback = { $true }
    $response = $null
    $source = $null
    $target = $null
    try {
        $response = $request.GetResponse()
        $source = $response.GetResponseStream()
        $target = [System.IO.File]::Create($Destination)
        $source.CopyTo($target)
    }
    finally {
        if ($target) { $target.Dispose() }
        if ($source) { $source.Dispose() }
        if ($response) { $response.Dispose() }
    }
}

function Start-TrustPSGallery {
    [CmdletBinding()]
    param ()
    $PSRepository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if (-not $PSRepository) {
        Write-Host -ForegroundColor DarkGray 'Register default PowerShell repositories'
        Register-PSRepository -Default -ErrorAction Stop
        $PSRepository = Get-PSRepository -Name PSGallery -ErrorAction Stop
    }

    if ($PSRepository.InstallationPolicy -ne 'Trusted') {
        Write-Host -ForegroundColor DarkGray 'Set-PSRepository PSGallery Trusted [CurrentUser]'
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
}

function Start-SetExecutionPolicy {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        if ((Get-ExecutionPolicy) -ne 'Bypass') {
            Write-Host -ForegroundColor DarkGray 'Set-ExecutionPolicy Bypass'
            Set-ExecutionPolicy Bypass -Force
        }
    }
    else {
        if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') {
            Write-Host -ForegroundColor DarkGray 'Set-ExecutionPolicy RemoteSigned [CurrentUser]'
            Set-ExecutionPolicy RemoteSigned -Force -Scope CurrentUser
        }
    }
}
function Install-PackageManagement {
    [CmdletBinding()]
    param ()
    $InstalledModule = Import-Module PackageManagement -PassThru -ErrorAction Ignore
    if (-not $InstalledModule) {
        Write-Host -ForegroundColor DarkGray 'Install PackageManagement'
        $PackageManagementURL = "https://cdn.powershellgallery.com/packages/packagemanagement.1.4.8.1.nupkg"
        Save-BootstrapPackage -Url $PackageManagementURL -Destination "$env:TEMP\packagemanagement.1.4.8.1.zip"
        $null = New-Item -Path "$env:TEMP\1.4.8.1" -ItemType Directory -Force
        Expand-Archive -Path "$env:TEMP\packagemanagement.1.4.8.1.zip" -DestinationPath "$env:TEMP\1.4.8.1"
        $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
        Move-Item -Path "$env:TEMP\1.4.8.1" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.8.1"
        Import-Module PackageManagement -Force -Scope Global
    }
}


function Install-PowerShellGet {
    [CmdletBinding()]
    param ()
    $InstalledModule = Import-Module PowerShellGet -PassThru -ErrorAction Ignore
    if (-not (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'})) {
        Write-Host -ForegroundColor DarkGray 'Install PowerShellGet'
        $PowerShellGetURL = "https://www.powershellgallery.com/api/v2/package/PowerShellGet/2.2.5"
        Save-BootstrapPackage -Url $PowerShellGetURL -Destination "$env:TEMP\powershellget.2.2.5.zip"
        $null = New-Item -Path "$env:TEMP\2.2.5" -ItemType Directory -Force
        Expand-Archive -Path "$env:TEMP\powershellget.2.2.5.zip" -DestinationPath "$env:TEMP\2.2.5"
        $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet" -ItemType Directory -ErrorAction SilentlyContinue
        Move-Item -Path "$env:TEMP\2.2.5" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\2.2.5"
        Import-Module PowerShellGet -Force -Scope Global
    }
}




Remove-Item "$env:ProgramFiles\WindowsPowerShell\Modules\PowerShellGet\*" -Recurse
Remove-Item "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\*" -Recurse

#Setup LOCALAPPDATA Variable
[System.Environment]::SetEnvironmentVariable('LOCALAPPDATA',"$env:SystemDrive\Windows\system32\config\systemprofile\AppData\Local")

$WorkingDir = $env:TEMP

Install-PackageManagement
Install-PowerShellGet
Start-TrustPSGallery