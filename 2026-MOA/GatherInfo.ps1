<#
1st Prompt
Using information Here: 
https://garytown.com/hp-bcu-to-hp-cmsl
https://garytown.com/dell-bios-management-native-wmi-cctk
https://www.configjon.com/lenovo-bios-settings-management/

Build a script that will gather all of the Current BIOS Settings and return as a PS Object

2nd prompt:
add additional function Set-BIOSSetting that will use the correct syntax invoke changing the BIOS setting. Allow piping from Get-BIOSSetting to Set-BIOSSetting

3rd prompt:
update so it also shows the optional values in the Get-AllBIOSSettings function

#>
function Get-AllBIOSSettings {
    <#
    .SYNOPSIS
        Gathers all current BIOS settings from HP, Dell, or Lenovo devices via native WMI.
    .DESCRIPTION
        Detects the manufacturer and queries the appropriate WMI namespace:
        - HP:     root\HP\InstrumentedBIOS -> HP_BIOSEnumeration
        - Dell:   root\dcim\sysman\biosattributes -> EnumerationAttribute + StringAttribute
        - Lenovo: root\wmi -> Lenovo_BiosSetting
    .OUTPUTS
        PSCustomObject[] with properties: Manufacturer, SettingName, CurrentValue, PossibleValues
    #>

    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer

    switch -Wildcard ($manufacturer) {

        '*HP*' {
            Write-Verbose "Detected HP device - querying root\HP\InstrumentedBIOS"
            try {
                $settings = Get-CimInstance -Namespace 'root\HP\InstrumentedBIOS' -ClassName HP_BIOSEnumeration -ErrorAction Stop
                $results = foreach ($s in $settings) {
                    [PSCustomObject]@{
                        Manufacturer    = 'HP'
                        SettingName     = $s.Name
                        CurrentValue    = $s.CurrentValue
                        PossibleValues  = $s.PossibleValues
                    }
                }
            }
            catch {
                Write-Warning "Failed to query HP BIOS WMI: $($_.Exception.Message)"
                $results = $null
            }
        }

        '*Hewlett*' {
            Write-Verbose "Detected HP (Hewlett-Packard) device - querying root\HP\InstrumentedBIOS"
            try {
                $settings = Get-CimInstance -Namespace 'root\HP\InstrumentedBIOS' -ClassName HP_BIOSEnumeration -ErrorAction Stop
                $results = foreach ($s in $settings) {
                    [PSCustomObject]@{
                        Manufacturer    = 'HP'
                        SettingName     = $s.Name
                        CurrentValue    = $s.CurrentValue
                        PossibleValues  = $s.PossibleValues
                    }
                }
            }
            catch {
                Write-Warning "Failed to query HP BIOS WMI: $($_.Exception.Message)"
                $results = $null
            }
        }

        '*Dell*' {
            Write-Verbose "Detected Dell device - querying root\dcim\sysman\biosattributes"
            try {
                $results = @()

                # Enumeration settings (settings with predefined values)
                $enumSettings = Get-CimInstance -Namespace 'root\dcim\sysman\biosattributes' -ClassName EnumerationAttribute -ErrorAction SilentlyContinue
                foreach ($s in $enumSettings) {
                    $results += [PSCustomObject]@{
                        Manufacturer    = 'Dell'
                        SettingName     = $s.AttributeName
                        CurrentValue    = $s.CurrentValue
                        PossibleValues  = $s.PossibleValues
                    }
                }

                # String settings (text-based like Asset Tag, Service Tag)
                $stringSettings = Get-CimInstance -Namespace 'root\dcim\sysman\biosattributes' -ClassName StringAttribute -ErrorAction SilentlyContinue
                foreach ($s in $stringSettings) {
                    $results += [PSCustomObject]@{
                        Manufacturer    = 'Dell'
                        SettingName     = $s.AttributeName
                        CurrentValue    = $s.CurrentValue
                        PossibleValues  = "String (Min: $($s.MinLength), Max: $($s.MaxLength))"
                    }
                }
            }
            catch {
                Write-Warning "Failed to query Dell BIOS WMI: $($_.Exception.Message)"
                $results = $null
            }
        }

        '*Lenovo*' {
            Write-Verbose "Detected Lenovo device - querying root\wmi Lenovo_BiosSetting"
            try {
                $settings = Get-CimInstance -Namespace 'root\wmi' -ClassName Lenovo_BiosSetting -ErrorAction Stop
                $selectionsInterface = Get-CimInstance -Namespace 'root\wmi' -ClassName Lenovo_GetBiosSelections -ErrorAction SilentlyContinue
                $results = foreach ($s in $settings) {
                    # Lenovo returns settings as "SettingName,SettingValue" in CurrentSetting
                    if (-not [string]::IsNullOrWhiteSpace($s.CurrentSetting)) {
                        $parts = $s.CurrentSetting -split ',', 2
                        $settingName = $parts[0]

                        # Get possible values via Lenovo_GetBiosSelections
                        $possibleValues = $null
                        if ($selectionsInterface -and $settingName) {
                            try {
                                $selResult = $selectionsInterface | Invoke-CimMethod -MethodName GetBiosSelections -Arguments @{ parameter = $settingName } -ErrorAction SilentlyContinue
                                if ($selResult.return -and $selResult.return -ne 'Invalid Parameter') {
                                    $possibleValues = ($selResult.return -split ',').Trim()
                                }
                            } catch { }
                        }

                        [PSCustomObject]@{
                            Manufacturer    = 'Lenovo'
                            SettingName     = $settingName
                            CurrentValue    = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                            PossibleValues  = $possibleValues
                        }
                    }
                }
            }
            catch {
                Write-Warning "Failed to query Lenovo BIOS WMI: $($_.Exception.Message)"
                $results = $null
            }
        }

        default {
            Write-Warning "Unsupported manufacturer: $manufacturer. Supported: HP, Dell, Lenovo."
            $results = $null
        }
    }

    return $results
}

function Set-BIOSSetting {
    <#
    .SYNOPSIS
        Sets a BIOS setting on HP, Dell, or Lenovo devices via native WMI.
    .DESCRIPTION
        Accepts pipeline input from Get-AllBIOSSettings. Detects the manufacturer and
        invokes the correct WMI method:
        - HP:     HP_BIOSSettingInterface -> SetBIOSSetting (root\HP\InstrumentedBIOS)
        - Dell:   BIOSAttributeInterface  -> SetAttribute   (root\dcim\sysman\biosattributes)
        - Lenovo: Lenovo_SetBiosSetting   -> SetBiosSetting (root\wmi) + Lenovo_SaveBiosSettings -> SaveBiosSettings
    .PARAMETER SettingName
        The BIOS setting name to change. Accepted from pipeline.
    .PARAMETER NewValue
        The new value to apply to the setting.
    .PARAMETER Password
        The BIOS password if one is set. For HP, utf-16 encoding is handled automatically.
    .EXAMPLE
        # Set a single setting by name
        Set-BIOSSetting -SettingName 'Fast Boot' -NewValue 'Disable'
    .EXAMPLE
        # Pipe from Get-AllBIOSSettings and change a specific setting
        Get-AllBIOSSettings | Where-Object { $_.SettingName -eq 'Fast Boot' } | Set-BIOSSetting -NewValue 'Disable'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$SettingName,

        [Parameter(Mandatory)]
        [string]$NewValue,

        [Parameter()]
        [string]$Password
    )

    process {
        # Auto-detect manufacturer
        $mfr = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
        $Manufacturer = switch -Wildcard ($mfr) {
            '*HP*'      { 'HP' }
            '*Hewlett*'  { 'HP' }
            '*Dell*'     { 'Dell' }
            '*Lenovo*'  { 'Lenovo' }
            default {
                Write-Error "Unsupported manufacturer: $mfr. Supported: HP, Dell, Lenovo."
                return
            }
        }

        if (-not $PSCmdlet.ShouldProcess("$SettingName = $NewValue", "Set BIOS Setting ($Manufacturer)")) { return }

        switch ($Manufacturer) {

            'HP' {
                # HP: root\HP\InstrumentedBIOS -> HP_BIOSSettingInterface -> SetBIOSSetting
                try {
                    $interface = Get-CimInstance -Namespace 'root\HP\InstrumentedBIOS' -ClassName HP_BIOSSettingInterface -ErrorAction Stop

                    # HP requires password in utf-16 format
                    if ($Password) {
                        $biosPassword = "<utf-16/>$Password"
                    } else {
                        $biosPassword = "<utf-16/>"
                    }

                    $result = $interface | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{
                        Name     = $SettingName
                        Value    = $NewValue
                        Password = $biosPassword
                    }

                    switch ($result.Return) {
                        0 { Write-Verbose "HP: '$SettingName' set to '$NewValue' successfully" }
                        1 { Write-Warning "HP: '$SettingName' - Not Supported" }
                        2 { Write-Warning "HP: '$SettingName' - Unspecified Error" }
                        3 { Write-Warning "HP: '$SettingName' - Operation Timed Out" }
                        4 { Write-Warning "HP: '$SettingName' - Operation Failed (setting may not exist on this model)" }
                        5 { Write-Warning "HP: '$SettingName' - Invalid Parameter" }
                        6 { Write-Warning "HP: '$SettingName' - Access Denied (incorrect password)" }
                        default { Write-Warning "HP: '$SettingName' - Unknown return code: $($result.Return)" }
                    }

                    [PSCustomObject]@{
                        Manufacturer = 'HP'
                        SettingName  = $SettingName
                        NewValue     = $NewValue
                        ReturnCode   = $result.Return
                        Success      = ($result.Return -eq 0)
                    }
                }
                catch {
                    Write-Error "HP: Failed to set '$SettingName': $($_.Exception.Message)"
                }
            }

            'Dell' {
                # Dell: root\dcim\sysman\biosattributes -> BIOSAttributeInterface -> SetAttribute
                try {
                    $interface = Get-CimInstance -Namespace 'root\dcim\sysman\biosattributes' -ClassName BIOSAttributeInterface -ErrorAction Stop

                    if ($Password) {
                        $encoder = [System.Text.UTF8Encoding]::new()
                        $pwdBytes = $encoder.GetBytes($Password)
                        $arguments = @{
                            AttributeName  = $SettingName
                            AttributeValue = $NewValue
                            SecType        = 1
                            SecHndCount    = $pwdBytes.Length
                            SecHandle      = $pwdBytes
                        }
                    } else {
                        $arguments = @{
                            AttributeName  = $SettingName
                            AttributeValue = $NewValue
                            SecType        = 0
                            SecHndCount    = 0
                            SecHandle      = @()
                        }
                    }

                    $result = Invoke-CimMethod -InputObject $interface -MethodName SetAttribute -Arguments $arguments -ErrorAction Stop

                    switch ($result.Status) {
                        0 { Write-Verbose "Dell: '$SettingName' set to '$NewValue' successfully" }
                        1 { Write-Warning "Dell: '$SettingName' - Failed" }
                        2 { Write-Warning "Dell: '$SettingName' - Invalid Parameter" }
                        3 { Write-Warning "Dell: '$SettingName' - Access Denied (incorrect password)" }
                        4 { Write-Warning "Dell: '$SettingName' - Not Supported" }
                        5 { Write-Warning "Dell: '$SettingName' - Memory Error" }
                        6 { Write-Warning "Dell: '$SettingName' - Protocol Error" }
                        default { Write-Warning "Dell: '$SettingName' - Unknown status: $($result.Status)" }
                    }

                    [PSCustomObject]@{
                        Manufacturer = 'Dell'
                        SettingName  = $SettingName
                        NewValue     = $NewValue
                        ReturnCode   = $result.Status
                        Success      = ($result.Status -eq 0)
                    }
                }
                catch {
                    Write-Error "Dell: Failed to set '$SettingName': $($_.Exception.Message)"
                }
            }

            'Lenovo' {
                # Lenovo: root\wmi -> Lenovo_SetBiosSetting -> SetBiosSetting, then Lenovo_SaveBiosSettings -> SaveBiosSettings
                try {
                    $setInterface  = Get-CimInstance -Namespace 'root\wmi' -ClassName Lenovo_SetBiosSetting -ErrorAction Stop
                    $saveInterface = Get-CimInstance -Namespace 'root\wmi' -ClassName Lenovo_SaveBiosSettings -ErrorAction Stop

                    # Lenovo format: "SettingName,SettingValue" or "SettingName,SettingValue,Password,ascii,us"
                    if ($Password) {
                        $setValue = "$SettingName,$NewValue,$Password,ascii,us"
                        $saveValue = "$Password,ascii,us"
                    } else {
                        $setValue = "$SettingName,$NewValue"
                        $saveValue = $null
                    }

                    $setResult = $setInterface | Invoke-CimMethod -MethodName SetBiosSetting -Arguments @{ parameter = $setValue }

                    if ($setResult.return -eq 'Success') {
                        # Commit the change
                        if ($saveValue) {
                            $saveResult = $saveInterface | Invoke-CimMethod -MethodName SaveBiosSettings -Arguments @{ parameter = $saveValue }
                        } else {
                            $saveResult = $saveInterface | Invoke-CimMethod -MethodName SaveBiosSettings
                        }

                        if ($saveResult.return -eq 'Success') {
                            Write-Verbose "Lenovo: '$SettingName' set to '$NewValue' and saved successfully"
                        } else {
                            Write-Warning "Lenovo: '$SettingName' was set but SaveBiosSettings returned: $($saveResult.return)"
                        }
                    } else {
                        Write-Warning "Lenovo: '$SettingName' - SetBiosSetting returned: $($setResult.return)"
                    }

                    [PSCustomObject]@{
                        Manufacturer = 'Lenovo'
                        SettingName  = $SettingName
                        NewValue     = $NewValue
                        ReturnCode   = $setResult.return
                        Success      = ($setResult.return -eq 'Success')
                    }
                }
                catch {
                    Write-Error "Lenovo: Failed to set '$SettingName': $($_.Exception.Message)"
                }
            }
        }
    }
}

# Run and output
$BIOSSettings = Get-AllBIOSSettings -Verbose
$BIOSSettings | Format-Table -AutoSize