#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates a one-time scheduled task, running as SYSTEM, that starts 30 minutes from now
    and clears the BranchCache cache until the active cache size is 0.

.DESCRIPTION
    When the task fires it will:
      1. Run Clear-BCCache -Force
      2. Wait 10 seconds
      3. Run Get-BCStatus and check DataCache.CurrentActiveCacheSize
      4. If it is not 0, repeat from step 1 (up to $MaxAttempts times)
#>
[CmdletBinding()]
param(
    [string]$TaskName = 'Clear-BCCache-OneTime',
    [int]$DelayMinutes = 30,
    [int]$WaitSeconds = 10,
    [int]$MaxAttempts = 10
)

$ErrorActionPreference = 'Stop'

# Script executed by the scheduled task
$taskScript = @"
for (`$i = 1; `$i -le $MaxAttempts; `$i++) {
    Clear-BCCache -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds $WaitSeconds
    if ((Get-BCStatus).DataCache.CurrentActiveCacheSize -eq 0) { exit 0 }
}
exit 1
"@

$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($taskScript))

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encoded"

$runAt = (Get-Date).AddMinutes($DelayMinutes)
$trigger = New-ScheduledTaskTrigger -Once -At $runAt

# Run as SYSTEM (no password or logged-on user required)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Force | Out-Null

Write-Host "Scheduled task '$TaskName' created to run as SYSTEM. It will run at $runAt." -ForegroundColor Green
