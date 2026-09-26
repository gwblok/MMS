<#
.SYNOPSIS
	Creates the HP directory on the EFI System Partition.

.DESCRIPTION
	Temporarily assigns K: to the EFI System Partition on disk 0, creates
	K:\EFI\HP, and removes the temporary drive-letter assignment. The folder
	remains on the EFI partition after it is no longer mounted in Windows.

.NOTES
	The EFI\HP folder must exist for the HP BIOS update workflow. HP BIOS
	update tools use this location on the EFI System Partition to stage or
	apply BIOS update files. Run with administrative privileges.
#>

$DriveLetter = "K"
$PartitionNumber = (Get-Partition | Where-Object {$_.DiskNumber -eq 0 -and $_.Type -eq "System"}).PartitionNumber
# Temporarily expose the EFI System Partition so its HP update directory can be created.
Get-Partition | Where-Object {$_.DiskNumber -eq 0 -and $_.Type -eq "System"} | Set-Partition -NewDriveLetter $DriveLetter 
New-Item -Path "K:\EFI\HP" -ItemType Directory -Force
# Remove only the temporary mount point; keep EFI\HP on the partition for HP BIOS updates.
Remove-PartitionAccessPath -DiskNumber 0 -PartitionNumber $PartitionNumber -Accesspath "$($DriveLetter):"