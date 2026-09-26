#Connects to TS Environment and Creates (confirms) Registry Stucture in place for the Win10 Upgrade Build.
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$NewBiosVersion = (Get-HPBiosUpdates -latest).ver
$CurrentBiosVersion = (Get-HPBiosVersion)


$tsenv.Value('SMSTS_NewBiosVersion') = $NewBiosVersion
$tsenv.Value('SMSTS_CurrentBiosVersion') = $CurrentBiosVersion
