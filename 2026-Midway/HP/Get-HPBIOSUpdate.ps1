<#
.SYNOPSIS
    Checks for and installs the latest applicable HP BIOS update.

.DESCRIPTION
    Uses HP Client Management PowerShell modules to compare the installed BIOS
    version with the latest available version, download the BIOS payload to a
    staging directory, and apply it with Update-HPFirmware when an update is
    available. Reports status in the Configuration Manager Task Sequence
    progress UI and writes CMTrace-formatted entries to HPBiosUpdate.log.

.PARAMETER BIOSPassword
    BIOS setup password supplied to Update-HPFirmware when a BIOS password is
    set. The script currently defaults this parameter to "P@ssw0rd"; provide
    the correct environment-specific password when that is not the device's
    configured password.

.NOTES
    Intended to run elevated in a Configuration Manager Task Sequence. The
    script reads and writes Task Sequence variables and uses the Task Sequence
    progress UI; running it outside a Task Sequence is not supported by its
    current implementation.

    The HP module family used by the script must already be installed and
    available to the running PowerShell session. It attempts to import
    HP.Firmware, HP.ClientManagement, HP.Repo, HP.Sinks, HP.Softpaq,
    HP.Softpaq.Shared, and HP.Warranty. Install those prerequisites before
    running this script.

    The BIOS payload is staged under %TEMP%\HPStaging. Review HPBiosUpdate.log
    in the Task Sequence log directory (or the temporary directory when no
    Task Sequence log path is available) when troubleshooting.

    BIOS firmware installation can require a restart. Ensure the Task Sequence
    handles the resulting reboot requirement appropriately.
#>


[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)][string]
		    $BIOSPassword = "P@ssw0rd"
	    )

#region: CMTraceLog Function formats logging in CMTrace style
        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "HPScriptLibrary",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

$Script:TaskSequenceEnvironment = $null
$Script:TaskSequenceProgressUi = $null


#region TSEnvironment

function Confirm-TSEnvironmentSetup()
{
    <#
    .SYNOPSIS
    Verifies the TSEnvironment Com Object is initiated into an object.
    
    .DESCRIPTION
    Verifies the TSEnvironment Com Object is initiated into an object.

    .INPUTS
    None

    .OUTPUTS
    None
    
    .NOTE
    This module can be used statically to initiate the TSEnvironment module, however, simply running one of the commands will initate it for you.

    #>

    if ($Script:TaskSequenceEnvironment -eq $null)
    {
        try
        {
            $Script:TaskSequenceEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment
        }
        catch
        {
            throw "Unable to connect to the Task Sequence Environment! Please verify you are in a running Task Sequence Environment.`n`nErrorDetails:`n$_"
        }
    }
}

function Get-TSVariables()
{
    <#
    .SYNOPSIS
    Get all Task Sequence Variable Names
    
    .DESCRIPTION
    Returns a string array of all Task Sequence Variable Names (not values).

    .INPUT
    None

    .OUTPUTS
    String[]

    .EXAMPLE
    $arrayOfVariableNames = Get-TSVariables

    #>
    Confirm-TSEnvironmentSetup

    $allVar = @()

    foreach ($variable in $Script:TaskSequenceEnvironment.GetVariables())
    {
        $allVar += $variable
    }

    return $allVar
}

function Get-TSValue()
{
    <#
    .SYNOPSIS
    Get a Task Sequence Variables Value
    
    .DESCRIPTION
    Obtains the value of a specific Task Sequence Variable.
    
    .PARAMETER Name
    Specifies the variable name to resolve.

    .INPUTS
    String

    .OUTPUTS
    String

    .EXAMPLE
    $OsdComputerName = Get-TSValue -Name "OSDComputerName"

    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name
    )

    Confirm-TSEnvironmentSetup

    return $Script:TaskSequenceEnvironment.Value($Name)
}

function Set-TSVariable()
{
    <#
    .SYNOPSIS
    Set or Create a Task Sequence Variables Value
    
    .DESCRIPTION
    Sets or Creates a Task Sequence Variables Value.
    Will return a boolean value indicating success or failure.
    
    .PARAMETER Name
    Specifies the variable name to set or create.

    .PARAMETER Value
    Specifies the variable value

    .INPUTS
     - Name: String
     - Value: System.Boolean

    .OUTPUTS
    System.Boolean

    .EXAMPLE
    Sets the OSDComputerName task sequence variable to "MyComputer123"
    $didSet = Set-TSVariable -Name "OSDComputerName" -Value "MyComputer123"

    .EXAMPLE
    Creates a new Task Sequence Variable, and sets its value
    $didSet = Set-TSVariable -Name "MyNewVar" -Value 'MyNewVarsValue"

    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name,
        [Parameter(Mandatory=$true)]
        [string] $Value
    )

    Confirm-TSEnvironmentSetup

    try
    {
        $Script:TaskSequenceEnvironment.Value($Name) = $Value
        return $true
    }
    catch
    {
        return $false
    }
}

function Get-TSAllValues()
{
    <#
    .SYNOPSIS
    Gets all Task Sequence Variables and Values
    
    .DESCRIPTION
    Gets all Task Sequence Variables with their associated values.

    .INPUTS
    None

    .OUTPUTS
    System.Object

    .EXAMPLE
    $TSVariableObject = Get-TSAllValues

    #>
    Confirm-TSEnvironmentSetup

    $Values = New-Object -TypeName System.Object

    foreach ($Variable in $Script:TaskSequenceEnvironment.GetVariables())
    {
        $Values | Add-Member -MemberType NoteProperty -Name $Variable -Value "$($Script:TaskSequenceEnvironment.Value($Variable))"
    }

    return $Values
}

#endregion

#region TSProgressUi

function Confirm-TSProgressUISetup()
{
    <#
    .SYNOPSIS
    Verifies the TSProgresUI Com Object is initiated into an object.
    
    .DESCRIPTION
    Verifies the TSProgresUI Com Object is initiated into an object.

    .INPUTS
    None

    .OUTPUTS
    None
    
    .NOTE
    This module can be used statically but is intended to be used by other functions.

    #>
    if ($Script:TaskSequenceProgressUi -eq $null)
    {
        try
        {
            $Script:TaskSequenceProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI
        }
        catch
        {
            throw "Unable to connect to the Task Sequence Progress UI! Please verify you are in a running Task Sequence Environment. Please note: TSProgressUI cannot be loaded during a prestart command.`n`nErrorDetails:`n$_"
        }
    }
}

function Show-TSActionProgress()
{
    <#
    .SYNOPSIS
    Shows task sequence secondary progress of a specific step
    
    .DESCRIPTION
    Adds a second progress bar to the existing Task Sequence Progress UI.
    This progress bar can be updated to allow for a real-time progress of
    a specific task sequence sub-step.

    The Step and Max Step parameters are calculated when passed. This allows
    you to have a "max steps" of 400, and update the step parameter. 100%
    would be achieved when step is 400 and max step is 400. The percentages
    are calculated behind the scenes by the Com Object.
    
    .PARAMETER Message
    The message to display the progress

    .PARAMETER Step
    Integer indicating current step

    .PARAMETER MaxStep
    Integer indicating 100%. A number other than 100 can be used.

    .INPUTS
     - Message: String
     - Step: Long
     - MaxStep: Long

    .OUTPUTS
    None

    .EXAMPLE
    Set's "Custom Step 1" at 30 percent complete
    Show-TSActionProgress -Message "Running Custom Step 1" -Step 100 -MaxStep 300
    
    .EXAMPLE
    Set's "Custom Step 1" at 50 percent complete
    Show-TSActionProgress -Message "Running Custom Step 1" -Step 150 -MaxStep 300

    .EXAMPLE
    Set's "Custom Step 1" at 100 percent complete
    Show-TSActionProgress -Message "Running Custom Step 1" -Step 300 -MaxStep 300


    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [Parameter(Mandatory=$true)]
        [long] $Step,
        [Parameter(Mandatory=$true)]
        [long] $MaxStep
    )

    Confirm-TSProgressUISetup
    Confirm-TSEnvironmentSetup

    $Script:TaskSequenceProgressUi.ShowActionProgress(`
        $Script:TaskSequenceEnvironment.Value("_SMSTSOrgName"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSCustomProgressDialogMessage"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSCurrentActionName"),`
        [Convert]::ToUInt32($Script:TaskSequenceEnvironment.Value("_SMSTSNextInstructionPointer")),`
        [Convert]::ToUInt32($Script:TaskSequenceEnvironment.Value("_SMSTSInstructionTableSize")),`
        $Message,`
        $Step,`
        $MaxStep)
}

function Close-TSProgressDialog()
{
    <#
    .SYNOPSIS
    Hides the Task Sequence Progress Dialog
    
    .DESCRIPTION
    Hides the Task Sequence Progress Dialog
    
    .INPUTS
    None

    .OUTPUTS
    None

    .EXAMPLE
    Close-TSProgressDialog

    #>
    Confirm-TSProgressUISetup

    $Script:TaskSequenceProgressUi.CloseProgressDialog()
}

function Show-TSProgress()
{
    <#
    .SYNOPSIS
    Shows task sequence progress of a specific step
    
    .DESCRIPTION
    Manipulates the Task Sequence progress UI; top progress bar only.
    This progress bar can be updated to allow for a real-time progress of
    a specific task sequence step.

    The Step and Max Step parameters are calculated when passed. This allows
    you to have a "max steps" of 400, and update the step parameter. 100%
    would be achieved when step is 400 and max step is 400. The percentages
    are calculated behind the scenes by the Com Object.
    
    .PARAMETER CurrentAction
    Step Title. Modifies the "Running action: " Message

    .PARAMETER Step
    Integer indicating current step

    .PARAMETER MaxStep
    Integer indicating 100%. A number other than 100 can be used.

    .INPUTS
     - CurrentAction: String
     - Step: Long
     - MaxStep: Long

    .OUTPUTS
    None

    .EXAMPLE
    Set's "Custom Step 1" at 30 percent complete
    Show-TSProgress -CurrentAction "Running Custom Step 1" -Step 100 -MaxStep 300
    
    .EXAMPLE
    Set's "Custom Step 1" at 50 percent complete
    Show-TSProgress -CurrentAction "Running Custom Step 1" -Step 150 -MaxStep 300

    .EXAMPLE
    Set's "Custom Step 1" at 100 percent complete
    Show-TSProgress -CurrentAction "Running Custom Step 1" -Step 300 -MaxStep 300
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $CurrentAction,
        [Parameter(Mandatory=$true)]
        [long] $Step,
        [Parameter(Mandatory=$true)]
        [long] $MaxStep
    )

    Confirm-TSProgressUISetup
    Confirm-TSEnvironmentSetup

    $Script:TaskSequenceProgressUi.ShowTSProgress(`
        $Script:TaskSequenceEnvironment.Value("_SMSTSOrgName"), `
        $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"), `
        $Script:TaskSequenceEnvironment.Value("_SMSTSCustomProgressDialogMessage"), `
        $CurrentAction, `
        $Step, `
        $MaxStep)

}

function Show-TSErrorDialog()
{
<#
    .SYNOPSIS
    Shows the Task Sequence Error Dialog
    
    .DESCRIPTION
    Shows a task sequence error dialog allowing for custom failure pages.
    
    .PARAMETER OrganizationName
    Name of your Organization

    .PARAMETER CustomTitle
    Custom Error Title

    .PARAMETER ErrorMessage
    Message details of the error

    .PARAMETER ErrorCode
    Error Code the Task sequence will exit with

    .PARAMETER TimeoutInSeconds
    Timout for the Reboot Prompt

    .PARAMETER ForceReboot
    Indicates whether a reboot will be forced or not

    .INPUTS
     - OrganizationName: String
     - CustomTitle: String
     - ErrorMessage: String
     - ErrorCode: Long
     - TimeoutInSeconds: Long
     - ForceReboot: System.Boolean
     - TSStepName: String

    .OUTPUTS
    None

    .EXAMPLE
    Sets an Error but does not force a reboot
    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "That thing you tried...it didnt work" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $false
    
    .EXAMPLE
    Sets an Error and forces a reboot
    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "He's dead Jim!" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $true

    .EXAMPLE
    Adds TSStepName which is required for SCCM 1901 TP and newer
    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "That thing you tried...it didnt work" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $false -TSStepName "My Step Name"
    
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $OrganizationName,
        [Parameter(Mandatory=$true)]
        [string] $CustomTitle,
        [Parameter(Mandatory=$true)]
        [string] $ErrorMessage,
        [Parameter(Mandatory=$true)]
        [long] $ErrorCode,
        [Parameter(Mandatory=$true)]
        [long] $TimeoutInSeconds,
        [Parameter(Mandatory=$true)]
        [bool] $ForceReboot,
        [Parameter()] #Required for SCCM 1901 Tech Preview and newer clients
        [string] $TSStepName
    )

    Confirm-TSProgressUISetup
    Confirm-TSEnvironmentSetup

    [int]$Reboot = Switch($ForceReboot) {
        $True {1}
        $False {0}
    }

    if([string]::IsNullOrEmpty($TSStepName)) {
        $Script:TaskSequenceProgressUi.ShowErrorDialog($OrganizationName, $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"), $CustomTitle, $ErrorMessage, $ErrorCode, $TimeoutInSeconds, $Reboot)
    }
    else {
        $Script:TaskSequenceProgressUi.ShowErrorDialog($OrganizationName, $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"), $CustomTitle, $ErrorMessage, $ErrorCode, $TimeoutInSeconds, $Reboot, $TSStepName)
    }
}

function Show-TSMessage()
{
    <#
    .SYNOPSIS
    Shows a Windows Forms Message Box
    
    .DESCRIPTION
    Shows a Windows Forms Message Box, but does not return the response.
    This will halt any current operations while the prompt is shown.
    
    .PARAMETER Message
    Message to be displayed

    .PARAMETER Title
    Title of the message box

    .PARAMETER Type
    Button Style for the MessageBox
    0 = OK
    1 = OK, Cancel
    2 = Abort, Retry, Ignore
    3 = Yes, No, Cancel
    4 = Yes, No
    5 = Retry, Cancel
    6 = Cancel, Try Again, Continue

    .INPUTS
     - Message: String
     - Title: String
     - Type: Long

    .OUTPUTS
    None

    .EXAMPLE
    Sets an Error but does not force a reboot
    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "That thing you tried...it didnt work" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $false
    
    .EXAMPLE
    Sets an Error and forces a reboot
    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "He's dead Jim!" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $true

    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [Parameter(Mandatory=$true)]
        [string] $Title,
        [Parameter(Mandatory=$true)]
        [ValidateRange(0,6)]
        [long] $Type
    )

    Confirm-TSProgressUISetup

    $Script:TaskSequenceProgressUi.ShowMessage($Message, $Title, $Type)

}

function Show-TSRebootDialog()
{
    <#
    .SYNOPSIS
    Shows the Reboot Dialog
    
    .DESCRIPTION
    Shows the Task Sequence "System Restart" Dialog. This allows you
    to trigger custom Task Sequence Reboot Messages.
    
    .PARAMETER OrganizationName
    Name of your Organization

    .PARAMETER CustomTitle
    Custom Title for the Reboot Dialog

    .PARAMETER Message
    Detailed Message regarding the reboot

    .PARAMETER TimeoutInSeconds
    Timout before the system reboots

    .INPUTS
     - OrganizationName: String
     - CustomTitle: String
     - Message: String
     - TimeoutInSeconds: Long

    .OUTPUTS
    None

    .EXAMPLE
    Show's a Reboot Dialog
    Show-TSRebootDialog -OrganizationName "My Organization" -CustomTitle "I need a reboot!" -Message "I need to reboot to complete something..." -TimeoutInSeconds 90
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $OrganizationName,
        [Parameter(Mandatory=$true)]
        [string] $CustomTitle,
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [Parameter(Mandatory=$true)]
        [long] $TimeoutInSeconds
    )

    Confirm-TSProgressUISetup
    Confirm-TSEnvironmentSetup

    $Script:TaskSequenceProgressUi.ShowRebootDialog($OrganizationName, $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"), $CustomTitle, $Message, $TimeoutInSeconds)
}

function Show-TSSwapMediaDialog()
{
<#
    .SYNOPSIS
    Shows Task Sequence Swap Media Dialog.
    
    .DESCRIPTION
    Shows Task Sequence Swap Media Dialog.
    
    .PARAMETER TaskSequenceName
    Name of the Task Sequence

    .PARAMETER MediaNumber
    Media Number to insert

    .INPUTS
     - TaskSequenceName: String
     - CustomTitle: Long

    .OUTPUTS
    None

    .EXAMPLE
    Prompts to insert media #2 for the Task Sequence "My Task Sequence"
    Show-TSSwapMediaDialog -TaskSequenceName "My Task Sequence" -MediaNumber 2
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $TaskSequenceName,
        [Parameter(Mandatory=$true)]
        [long] $MediaNumber
    )

    Confirm-TSProgressUISetup

    $Script:TaskSequenceProgressUi.ShowSwapMediaDialog($TaskSequenceName, $MediaNumber)

}

#endregion



try
{
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
}
catch
{
	Write-Verbose "Not running in a task sequence."
}
if ($tsenv)
    {
    $LogPath = $tsenv.Value('_SMSTSLogPath')
    $tsPUI = New-Object -ComObject Microsoft.SMS.TSProgressUI
    }
else
    {
    $LogPath = $env:TEMP
    }   

Import-Module HP.Firmware -Force -ErrorAction SilentlyContinue
Import-Module HP.ClientManagement -Force -ErrorAction SilentlyContinue
Import-Module HP.Repo -Force -ErrorAction SilentlyContinue
Import-Module HP.Sinks -Force -ErrorAction SilentlyContinue
Import-Module HP.Softpaq -Force -ErrorAction SilentlyContinue
Import-Module HP.Softpaq.Shared -Force -ErrorAction SilentlyContinue
Import-Module HP.Warranty -Force -ErrorAction SilentlyContinue


$LogFile = "$LogPath\HPBiosUpdate.log"
$ScriptName = $MyInvocation.MyCommand.Name
$NewBiosVersion = (Get-HPBiosUpdates -latest).ver
$CurrentBiosVersion = (Get-HPBiosVersion)
$tsenv.Value('SMSTS_NewBiosVersion') = $NewBiosVersion
$tsenv.Value('SMSTS_CurrentBiosVersion') = $CurrentBiosVersion
$StagingTemp = "$env:temp\HPStaging"
New-Item -Path $StagingTemp -ItemType Directory -Force

CMTraceLog -Message  "Starting BIOS Flash TS Step" -Type 2 -LogFile $LogFile
CMTraceLog -Message  "  Model: $($tsenv.value('Model'))" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "  Current Installed BIOS: $CurrentBiosVersion" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "  Current Online BIOS: $NewBiosVersion" -Type 1 -LogFile $LogFile

$PasswordSet = Get-HPBiosSetupPasswordIsSet
if ($PasswordSet -eq $true)
    {
    Write-Output "BIOS PASSWORD SET"
    Show-TSActionProgress -Message "This $($tsenv.value('Model')) has a BIOS Password" -Step 1 -MaxStep 100
    CMTraceLog -Message  "BIOS PASSWORD SET" -Type 1 -LogFile $LogFile
    }
else
    {
    Write-Output "NO BIOS PASSWORD"
    Show-TSActionProgress -Message "This $($tsenv.value('Model')) has a BIOS Password" -Step 1 -MaxStep 100
    CMTraceLog -Message  "NO BIOS PASSWORD" -Type 1 -LogFile $LogFile
    }

Start-Sleep 3 #Time for Messages to be read if someone is watching.

if ($CurrentBiosVersion -lt $NewBiosVersion)
    {
    Show-TSActionProgress -Message "Downloadling BIOS Update $NewBiosVersion for $($tsenv.value('Model'))" -Step 5 -MaxStep 100
    $LatestBiosName = Get-HPBiosUpdates -latest
    $LatestBiosName = $LatestBiosName.bin
    Get-HPBiosUpdates -download -saveAs "$($StagingTemp)\$($LatestBiosName)" -overwrite
    Show-TSActionProgress -Message "Downloaded BIOS: $($StagingTemp)\$($LatestBiosName)" -Step 50 -MaxStep 100
    CMTraceLog -Message  "Downloaded BIOS: $($StagingTemp)\$($LatestBiosName)" -Type 1 -LogFile $LogFile
    
    Write-Output "Upgrading from $CurrentBiosVersion to $NewBiosVersion"
    CMTraceLog -Message  "Upgrading from $CurrentBiosVersion to $NewBiosVersion" -Type 1 -LogFile $LogFile
    Start-Sleep 5 #Time for Messages to be read if someone is watching.
    
    if ($PasswordSet -eq $true)
        {
        Show-TSActionProgress -Message "Updating BIOS from $CurrentBiosVersion to $NewBiosVersion on $($tsenv.value('Model'))" -Step 55 -MaxStep 100
        CMTraceLog -Message  "Running Update-HPFirmware -file ""$($StagingTemp)\$($LatestBiosName)"" -password $BIOSPassword -bitlocker ignore -Verbose" -Type 1 -LogFile $LogFile
        Write-Output "Running Update-HPFirmware -file ""$($StagingTemp)\$($LatestBiosName)"" -password $BIOSPassword -bitlocker ignore -Verbose"
        Update-HPFirmware -file "$($StagingTemp)\$($LatestBiosName)" -password $BIOSPassword -bitlocker ignore -Verbose
        Show-TSActionProgress -Message "BIOS Updated, Reboot Required" -Step 100 -MaxStep 100
        Start-Sleep 5 #Time for Messages to be read if someone is watching.
        CMTraceLog -Message  "Updated BIOS, Requires Reboot" -Type 1 -LogFile $LogFile
        }
    Else
        {
        Show-TSActionProgress -Message "Updating BIOS from $CurrentBiosVersion to $NewBiosVersion on $($tsenv.value('Model'))" -Step 55 -MaxStep 100
        Write-Output "Running: Update-HPFirmware -file ""$($StagingTemp)\$($LatestBiosName)"" -password $BIOSPassword -bitlocker ignore -Verbose"
        CMTraceLog -Message  "Running Update-HPFirmware -file ""$($StagingTemp)\$($LatestBiosName)"" -bitlocker ignore -Verbose" -Type 1 -LogFile $LogFile
        (Update-HPFirmware -file "$($StagingTemp)\$($LatestBiosName)" -bitlocker ignore -Verbose).exitcode
        Show-TSActionProgress -Message "BIOS Updated, Reboot Required" -Step 100 -MaxStep 100
        Start-Sleep 5 #Time for Messages to be read if someone is watching.
        CMTraceLog -Message  "Updated BIOS, Requires Reboot" -Type 1 -LogFile $LogFile
        }
    }
Else {
    Write-Output "No need to upgrade"
    CMTraceLog -Message  "No need to upgrade BIOS" -Type 1 -LogFile $LogFile
}
