#Load Lenovo EMPS
Clear-Host



Write-Host "Import the Lenovo Module..." -ForegroundColor Green
Write-Host 'Import-Module Lenovo.Client.Scripting' -ForegroundColor Cyan
Install-Module 'Lenovo.Client.Scripting' -scope AllUsers -Force
Write-Host ""
#Pause The Script 
Write-Host "Press any key to continue..." -ForegroundColor Green
Read-Host
write-host "Listing Lenovo Functions" -ForegroundColor Green
get-command -Module Lenovo.Client.Scripting
Write-Host ""
Read-Host
Write-Host "Lets Run Several and see what they respond with" -ForegroundColor Magenta
Write-Host ""
Write-Host "Get-LnvMachineType          | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvMachineType)"
Write-Host "Get-LnvModelName            | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvModelName)"
Write-Host "Get-LnvProductNumber        | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvProductNumber )"
Write-Host "Get-LnvSerial               | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvSerial)"
Write-Host "Get-LnvBiosCode             | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvBiosCode)"
Write-Host "Get-LnvBiosPasswordsSet     | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvBiosPasswordsSet)"
Write-Host "Get-LnvBiosUpdateUrl        | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvBiosUpdateUrl)"
Write-Host "Get-LnvBiosVersion          | "-ForegroundColor Green -NoNewline; Write-Host -ForegroundColor Cyan "$(Get-LnvBiosVersion)"
Write-Host ""
Write-Host ""
Read-Host

Write-Host "Find-LnvModel" -ForegroundColor Green
Write-Host "Find-LnvModel -MachineType (Get-LnvMachineType)" -ForegroundColor Cyan
Read-Host
Find-LnvModel -MachineType (Get-LnvMachineType)
Write-Host ""
Write-Host "Find-LnvModel -MachineType 11VL" -ForegroundColor Cyan
Read-Host
Find-LnvModel -MachineType 11VL
Write-Host ""
Write-Host "Find-LnvMachineType" -ForegroundColor Green
Write-Host 'Find-LnvMachineType -ModelName "M80"' -ForegroundColor Cyan
Read-Host
Find-LnvMachineType -ModelName "M80"
Write-Host ""
Write-Host ""
Read-Host
Write-Host "Find-LnvTool" -ForegroundColor Green
Write-Host "We're going to run this tool with several quick examples" -ForegroundColor yellow
Read-Host
Write-Host "Find-LnvTool -Tool DockManager" -ForegroundColor Cyan
Find-LnvTool -Tool DockManager
Write-Host ""
Write-Host "Find-LnvTool -Tool SystemUpdate" -ForegroundColor Cyan
Find-LnvTool -Tool SystemUpdate
Write-Host ""
Write-Host "Find-LnvTool -Tool ThinInstaller" -ForegroundColor Cyan
Find-LnvTool -Tool ThinInstaller
Write-Host ""
Write-Host "Find-LnvTool -Tool UpdateRetriever" -ForegroundColor Cyan 
Find-LnvTool -Tool UpdateRetriever
Write-Host ""
Write-Host ""
Read-Host

Write-Host "Get-LnvAvailableBiosVersion" -ForegroundColor Green
Get-LnvAvailableBiosVersion

Write-Host ""
Read-Host

Write-Host "Get-LnvBiosInfo" -ForegroundColor Green
Get-LnvBiosInfo

Write-Host ""
Read-Host

Write-Host "Lets look at some Updates now" -ForegroundColor Magenta
Write-Host ""
Write-Host "Find-LnvUpdate" -ForegroundColor Green
Write-Host "Find-LnvUpdate -MachineType (Get-LnvMachineType)" -ForegroundColor Cyan
Write-Host ""
Read-Host
Find-LnvUpdate -MachineType (Get-LnvMachineType)

Write-Host ""
Read-Host
Write-Host "Find-LnvUpdate -MachineType (Get-LnvMachineType) -ListAll" -ForegroundColor Cyan
Write-Host ""
Read-Host
Find-LnvUpdate -MachineType (Get-LnvMachineType) -ListAll

Write-Host ""
Read-Host

Write-Host "Driver Pack Time!" -ForegroundColor Magenta
Write-Host ""
Write-Host "Find-LnvDriverPack | " -ForegroundColor Green -NoNewline; Write-Host "Find-LnvDriverPack -MachineType (Get-LnvMachineType) -Latest" -ForegroundColor Cyan
Find-LnvDriverPack -MachineType (Get-LnvMachineType) -Latest
Write-Host ""

Write-Host "Now to show the Install-LVC scripts for Lenovo Commercial Vantage" -ForegroundColor Green