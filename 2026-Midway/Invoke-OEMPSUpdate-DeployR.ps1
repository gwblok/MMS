<#
.SYNOPSIS
    Detects the OEM (HP, Dell, Lenovo, Panasonic), imports the matching module
    installed by InstallModule-OEMByManufacturer.ps1, and runs the OEM update.

.NOTES
    Run as Administrator or ConfigMgr SYSTEM.
    The Lenovo update runs in a separate, monitored pwsh.exe (PowerShell 7) process.
    Detection logic follows the DeployR MakeAlias / ModelAlias / SystemAlias code.
#>

$ErrorActionPreference = 'Stop'

# Determine OEM (same logic as DeployR MakeAlias)
$LocalInfo = @{}
$LocalInfo['Make'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer.Trim()
switch -Wildcard ($LocalInfo['Make']) {
    '*Hewlett-Packard*' {
        $LocalInfo['MakeAlias'] = 'HP'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()
        $LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName MS_SystemInformation -Namespace root\wmi).BaseBoardProduct.Trim()
    }
    '*HP*' {
        $LocalInfo['MakeAlias'] = 'HP'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()
        $LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName MS_SystemInformation -Namespace root\wmi).BaseBoardProduct.Trim()
    }
    '*Dell*' {
        $LocalInfo['MakeAlias'] = 'Dell'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()
        $LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName MS_SystemInformation -Namespace root\wmi).SystemSku.Trim()
    }
    '*Lenovo*' {
        $LocalInfo['MakeAlias'] = 'Lenovo'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).Version.Trim()
        $LocalInfo['SystemAlias'] = ((Get-CimInstance -ClassName Win32_ComputerSystem).Model.Substring(0, 4)).Trim()
    }
    '*Panasonic*' {
        $LocalInfo['MakeAlias'] = 'Panasonic Corporation'
        $LocalInfo['ModelAlias'] = (Get-CimInstance -ClassName Win32_ComputerSystem).Model.Trim()
        $LocalInfo['SystemAlias'] = (Get-CimInstance -ClassName MS_SystemInformation -Namespace root\wmi).BaseBoardProduct.Trim()
    }
    default {
        $LocalInfo['MakeAlias'] = 'NA'
        $LocalInfo['ModelAlias'] = 'NA'
        $LocalInfo['SystemAlias'] = 'NA'
    }
}

Write-Host "Manufacturer: $($LocalInfo['Make']) | MakeAlias: $($LocalInfo['MakeAlias']) | Model: $($LocalInfo['ModelAlias']) | System: $($LocalInfo['SystemAlias'])" -ForegroundColor Cyan

switch ($LocalInfo['MakeAlias']) {
    'HP' {
        Import-Module -Name OEMWrapPS -Force -ErrorAction Stop
        Get-HPUpdate | Install-HPUpdate -Force
    }
    'Dell' {
        Import-Module -Name OEMWrapPS -Force -ErrorAction Stop
        Get-DellUpdate | Install-DellUpdate -Force
    }
    'Lenovo' {
        $pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
        if (-not (Test-Path -Path $pwshPath)) {
            $pwshCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
            if ($pwshCommand) { $pwshPath = $pwshCommand.Source }
        }
        if (-not (Test-Path -Path $pwshPath)) {
            throw 'PowerShell 7 (pwsh.exe) was not found. Install PowerShell 7 before running the Lenovo update.'
        }

        $lenovoScript = @'
$ErrorActionPreference = 'Stop'
try {
    Import-Module -Name Lenovo.Client.Update -Force
    $updates = @(Get-LnvUpdate)
    Write-Output "Lenovo updates found: $($updates.Count)"
    if ($updates.Count -gt 0) {
        $updates | Install-LnvUpdate | Format-List | Out-String -Width 4096
    }
    exit 0
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    Write-Output $_.ScriptStackTrace
    exit 1
}
'@
        $encodedScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($lenovoScript))

        $logFolder = Join-Path $env:TEMP 'LenovoUpdate'
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
        $stdoutLog = Join-Path $logFolder 'pwsh-stdout.log'
        $stderrLog = Join-Path $logFolder 'pwsh-stderr.log'

        $startParameters = @{
            FilePath = $pwshPath
            ArgumentList = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encodedScript)
            RedirectStandardOutput = $stdoutLog
            RedirectStandardError = $stderrLog
            WindowStyle = 'Hidden'
            PassThru = $true
        }
        $process = Start-Process @startParameters
        $null = $process.Handle # Cache the handle so ExitCode is readable after exit.
        Write-Host "Started pwsh.exe (PID $($process.Id)) for the Lenovo update. Logs: $logFolder" -ForegroundColor Cyan

        $timeoutMinutes = 60
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(30000)) {
            Write-Host "Lenovo update still running... $([int]$stopwatch.Elapsed.TotalMinutes) min elapsed" -ForegroundColor Cyan
            if ($stopwatch.Elapsed.TotalMinutes -ge $timeoutMinutes) {
                & taskkill.exe /PID $process.Id /T /F | Out-Null
                throw "Lenovo update exceeded $timeoutMinutes minutes and was stopped."
            }
        }

        foreach ($logFile in $stdoutLog, $stderrLog) {
            if (Test-Path -Path $logFile) { Get-Content -Path $logFile | ForEach-Object { Write-Host $_ } }
        }

        if ($process.ExitCode -ne 0) {
            throw "Lenovo update failed in pwsh.exe with exit code $($process.ExitCode)."
        }
        Write-Host 'Lenovo update completed.' -ForegroundColor Green
    }
    'Panasonic Corporation' {
        Import-Module -Name PanasonicCommandUpdate -Force -ErrorAction Stop
        Show-PanasonicUpdate -AcceptLicense | Install-PanasonicUpdate -AcceptLicense -Force
    }
    default {
        throw "Unsupported computer manufacturer: $($LocalInfo['Make'])"
    }
}
