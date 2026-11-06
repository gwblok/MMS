Import-Module OEMWrapPS

#Invokes Dell Command Update to check for updates
Invoke-DCU -autoSuspendBitLocker Enable -reboot Disable -applyUpdates
