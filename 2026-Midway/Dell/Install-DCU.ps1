Import-Module OEMWrapPS

#Installs Dell Command Update and .NET Framework if needed
Get-DCUAppUpdates -Install -AutoInstallPreReqs