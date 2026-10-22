


#Delete's System's Boot Folder, reboots to PXE
$Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
$SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
$SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
$SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
Copy-Item -Path "$($SystemVolume.Path)\EFI\Microsoft\Boot" -Destination "$($SystemVolume.Path)\EFI\Microsoft\Boot.bak" -Force

#Restart
Restart-Computer