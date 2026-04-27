[CmdletBinding()]
param(
	[switch]$AsObject,
	[switch]$Quiet
)

function Invoke-DownloadFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Url,
		[Parameter(Mandatory = $true)]
		[string]$Destination
	)

	$destinationFolder = Split-Path -Path $Destination -Parent
	if (-not (Test-Path -Path $destinationFolder)) {
		$null = New-Item -Path $destinationFolder -ItemType Directory -Force
	}

	Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
}

function Expand-CabFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$CabPath,
		[Parameter(Mandatory = $true)]
		[string]$DestinationFile
	)

	$destinationFolder = Split-Path -Path $DestinationFile -Parent
	if (-not (Test-Path -Path $destinationFolder)) {
		$null = New-Item -Path $destinationFolder -ItemType Directory -Force
	}

	if (Test-Path -Path $DestinationFile) {
		Remove-Item -Path $DestinationFile -Force -ErrorAction SilentlyContinue
	}

	$expandExe = Join-Path -Path $env:SystemRoot -ChildPath 'System32\expand.exe'
	$null = & $expandExe $CabPath $DestinationFile

	if (-not (Test-Path -Path $DestinationFile)) {
		throw "Failed to expand CAB file $CabPath"
	}
}

function Get-TempWorkingPath {
	$path = Join-Path -Path $env:TEMP -ChildPath 'OEMBiosInfo'
	if (-not (Test-Path -Path $path)) {
		$null = New-Item -Path $path -ItemType Directory -Force
	}
	return $path
}

function Get-ComputerDetails {
	$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
	$bios = Get-CimInstance -ClassName Win32_BIOS
	$product = Get-CimInstance -ClassName Win32_ComputerSystemProduct
	$baseBoard = Get-CimInstance -ClassName Win32_BaseBoard

	[PSCustomObject]@{
		Manufacturer        = $computerSystem.Manufacturer
		Model               = $computerSystem.Model
		SystemSkuNumber     = $computerSystem.SystemSKUNumber
		SMBIOSBIOSVersion   = $bios.SMBIOSBIOSVersion
		BIOSMajorVersion    = $bios.SystemBIOSMajorVersion
		BIOSMinorVersion    = $bios.SystemBIOSMinorVersion
		ReleaseDate         = $bios.ReleaseDate
		ProductName         = $product.Name
		ProductVersion      = $product.Version
		BaseBoardProduct    = $baseBoard.Product
	}
}

function ConvertTo-ComparableVersion {
	param(
		[AllowNull()]
		[string]$VersionString
	)

	if ([string]::IsNullOrWhiteSpace($VersionString)) {
		return $null
	}

	$primaryMatch = [regex]::Match($VersionString, '\d+(?:\.\d+){1,3}')
	if ($primaryMatch.Success) {
		try {
			return [version]$primaryMatch.Value
		}
		catch {
		}
	}

	$parts = [regex]::Matches($VersionString, '\d+') | ForEach-Object { $_.Value }
	if ($parts.Count -ge 2) {
		$joined = ($parts | Select-Object -First 4) -join '.'
		try {
			return [version]$joined
		}
		catch {
		}
	}

	return $null
}

function Get-ResultObject {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Manufacturer,
		[Parameter(Mandatory = $true)]
		[string]$Model,
		[Parameter(Mandatory = $true)]
		[string]$CurrentBiosVersion,
		[Parameter(Mandatory = $true)]
		[string]$LatestBiosVersion,
		[Parameter(Mandatory = $true)]
		[bool]$IsCurrent,
		[string]$CurrentBiosDate,
		[string]$LatestBiosDate,
		[string]$Source
	)

	[PSCustomObject]@{
		Manufacturer       = $Manufacturer
		Model              = $Model
		CurrentBiosVersion = $CurrentBiosVersion
		LatestBiosVersion  = $LatestBiosVersion
		CurrentBiosDate    = $CurrentBiosDate
		LatestBiosDate     = $LatestBiosDate
		IsCurrent          = $IsCurrent
		Source             = $Source
	}
}

function Get-DellSupportedModelsStandalone {
	$workingPath = Get-TempWorkingPath
	$cabPath = Join-Path -Path $workingPath -ChildPath 'CatalogIndexPC.cab'
	$xmlPath = Join-Path -Path $workingPath -ChildPath 'CatalogIndexPC.xml'

	Invoke-DownloadFile -Url 'https://downloads.dell.com/catalog/CatalogIndexPC.cab' -Destination $cabPath
	Expand-CabFile -CabPath $cabPath -DestinationFile $xmlPath

	[xml]$catalogXml = Get-Content -Path $xmlPath
	$supportedModels = foreach ($supportedModel in $catalogXml.ManifestIndex.GroupManifest) {
		[PSCustomObject]@{
			SystemID = [string]$supportedModel.SupportedSystems.Brand.Model.systemID
			Model    = [string]$supportedModel.SupportedSystems.Brand.Model.Display.'#cdata-section'
			Url      = [string]$supportedModel.ManifestInformation.path
			Date     = [string]$supportedModel.ManifestInformation.version
		}
	}

	return $supportedModels
}

function Get-DellLatestBiosInfo {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	$supportedModel = Get-DellSupportedModelsStandalone | Where-Object { $_.SystemID -match $ComputerDetails.SystemSkuNumber } | Select-Object -First 1
	if (-not $supportedModel) {
		throw "Dell System SKU $($ComputerDetails.SystemSkuNumber) was not found in the Dell catalog"
	}

	$workingPath = Get-TempWorkingPath
	$cabPath = Join-Path -Path $workingPath -ChildPath 'CatalogIndexModel.cab'
	$xmlPath = Join-Path -Path $workingPath -ChildPath 'CatalogIndexModel.xml'
	Invoke-DownloadFile -Url ("https://downloads.dell.com/{0}" -f $supportedModel.Url) -Destination $cabPath
	Expand-CabFile -CabPath $cabPath -DestinationFile $xmlPath

	[xml]$catalogXml = Get-Content -Path $xmlPath
	$baseUrl = "https://{0}" -f $catalogXml.Manifest.baseLocation

	$biosUpdates = foreach ($component in $catalogXml.Manifest.SoftwareComponent) {
		$type = [string]$component.ComponentType.Display.'#cdata-section'
		if ($type -notin @('BIOS', 'bios')) {
			continue
		}

		[PSCustomObject]@{
			Name        = [string]$component.Name.Display.'#cdata-section'
			ReleaseDate = [datetime]$component.releaseDate
			DellVersion = [string]$component.dellVersion
			Path        = "{0}/{1}" -f $baseUrl, [string]$component.path
		}
	}

	$latest = $biosUpdates | Sort-Object -Property ReleaseDate -Descending | Select-Object -First 1
	if (-not $latest) {
		throw 'No Dell BIOS update was found in the Dell catalog'
	}

	$currentComparable = ConvertTo-ComparableVersion -VersionString $ComputerDetails.SMBIOSBIOSVersion
	$latestComparable = ConvertTo-ComparableVersion -VersionString $latest.DellVersion
	$isCurrent = $false

	if ($currentComparable -and $latestComparable) {
		$isCurrent = $currentComparable -ge $latestComparable
	}
	else {
		$isCurrent = ($ComputerDetails.SMBIOSBIOSVersion -eq $latest.DellVersion)
	}

	return (Get-ResultObject -Manufacturer 'Dell' -Model $ComputerDetails.Model -CurrentBiosVersion $ComputerDetails.SMBIOSBIOSVersion -LatestBiosVersion $latest.DellVersion -CurrentBiosDate ([string]$ComputerDetails.ReleaseDate) -LatestBiosDate ([string]$latest.ReleaseDate) -IsCurrent $isCurrent -Source 'Dell Catalog')
}

function Get-LenovoMachineTypeStandalone {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	return $ComputerDetails.ProductName.Substring(0, 4)
}

function Get-LenovoCurrentBiosVersionStandalone {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	if ($ComputerDetails.ProductVersion -like 'ThinkPad*') {
		$major = [string]$ComputerDetails.BIOSMajorVersion
		$minor = ([string]$ComputerDetails.BIOSMinorVersion).PadLeft(2, '0')
		return "$major.$minor"
	}

	if ($ComputerDetails.ProductVersion -like 'ThinkCentre*' -or $ComputerDetails.ProductVersion -like 'ThinkStation*') {
		$hex = '0x' + $ComputerDetails.SMBIOSBIOSVersion.Substring(5, 2)
		return ([string]$ComputerDetails.BIOSMajorVersion + '.' + [Convert]::ToInt32($hex, 16))
	}

	return $ComputerDetails.SMBIOSBIOSVersion
}

function Get-LenovoXmlFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Url
	)

	$response = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
	$xml = New-Object System.Xml.XmlDocument
	$xml.LoadXml($response.Content)
	return $xml
}

function Get-LenovoLatestBiosInfo {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	$machineType = Get-LenovoMachineTypeStandalone -ComputerDetails $ComputerDetails
	$currentVersion = Get-LenovoCurrentBiosVersionStandalone -ComputerDetails $ComputerDetails
	$catalogUrls = @(
		"https://download.lenovo.com/catalog/${machineType}_win11.xml",
		"https://download.lenovo.com/catalog/${machineType}_win10.xml"
	)

	$packageUrls = @()
	foreach ($catalogUrl in $catalogUrls) {
		try {
			$catalogXml = Get-LenovoXmlFile -Url $catalogUrl
			$urls = $catalogXml.packages.ChildNodes | Where-Object { $_.category -match 'BIOS UEFI' } | ForEach-Object { $_.location }
			if ($urls) {
				$packageUrls += $urls
			}
		}
		catch {
		}
	}

	if (-not $packageUrls) {
		throw "No Lenovo BIOS catalog entries were found for machine type $machineType"
	}

	$highestVersion = $null
	$highestReleaseDate = $null

	foreach ($url in $packageUrls) {
		try {
			$packageXml = Get-LenovoXmlFile -Url $url
			$packageTitle = $packageXml.Package.Title.Desc.InnerText
			if ($packageTitle.StartsWith('System Firmware', [System.StringComparison]::OrdinalIgnoreCase)) {
				$baseUrl = $url.Substring(0, $url.LastIndexOf('/') + 1)
				$readmeUrl = $baseUrl + $packageXml.Package.Files.ReadMe.File.Name
				$readme = (New-Object System.Net.WebClient).DownloadString($readmeUrl)
				$match = [regex]::Match($readme, '(\d+\.\d+)&nbsp;&nbsp;\(UEFI BIOS\)')
				if ($match.Success) {
					$packageVersion = $match.Groups[1].Value
				}
				else {
					continue
				}
			}
			else {
				$packageVersion = [string]$packageXml.Package.version
			}

			$releaseDate = [string]$packageXml.Package.ReleaseDate

			if (($packageXml.Package.Files.Installer.File.Name) -like '*jy*') {
				$packageVersionHex = '0x' + $packageVersion.Substring(5, 2)
				$packageVersion = '1.' + [Convert]::ToInt32($packageVersionHex, 16)
			}
			else {
				$packageVersion = $packageVersion.Substring(0, 4)
			}

			if (($null -eq $highestVersion) -or ((ConvertTo-ComparableVersion -VersionString $packageVersion) -gt (ConvertTo-ComparableVersion -VersionString $highestVersion))) {
				$highestVersion = $packageVersion
				$highestReleaseDate = $releaseDate
			}
		}
		catch {
		}
	}

	if (-not $highestVersion) {
		throw 'No Lenovo BIOS version could be parsed from the Lenovo catalog'
	}

	$currentComparable = ConvertTo-ComparableVersion -VersionString $currentVersion
	$latestComparable = ConvertTo-ComparableVersion -VersionString $highestVersion
	$isCurrent = $false

	if ($currentComparable -and $latestComparable) {
		$isCurrent = $currentComparable -ge $latestComparable
	}
	else {
		$isCurrent = ($currentVersion -eq $highestVersion)
	}

	return (Get-ResultObject -Manufacturer 'Lenovo' -Model $ComputerDetails.Model -CurrentBiosVersion $currentVersion -LatestBiosVersion $highestVersion -CurrentBiosDate ([string]$ComputerDetails.ReleaseDate) -LatestBiosDate $highestReleaseDate -IsCurrent $isCurrent -Source 'Lenovo Catalog')
}

function Get-HPPlatformListXml {
	$workingPath = Get-TempWorkingPath
	$cabPath = Join-Path -Path $workingPath -ChildPath 'HPPlatformList.cab'
	$xmlPath = Join-Path -Path $workingPath -ChildPath 'HPPlatformList.xml'
	Invoke-DownloadFile -Url 'https://hpia.hpcloud.hp.com/ref/platformList.cab' -Destination $cabPath
	Expand-CabFile -CabPath $cabPath -DestinationFile $xmlPath
	[xml]$xml = Get-Content -Path $xmlPath
	return $xml
}

function Get-HPSupportedOsInfo {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Platform
	)

	$platformXml = Get-HPPlatformListXml
	$osList = ($platformXml.ImagePal.Platform | Where-Object { $_.SystemID -match $Platform }).OS | Select-Object OSReleaseIdDisplay, OSBuildId, OSDescription
	if (-not $osList) {
		throw "No HP OS support information was found for platform $Platform"
	}

	$maxOsSupported = ($osList.OSDescription | Where-Object { $_ -notmatch 'LTSB' } | Select-Object -Unique | Measure-Object -Maximum).Maximum
	$maxReleaseId = (($osList | Where-Object { $_.OSDescription -eq $maxOsSupported }).OSReleaseIdDisplay | Measure-Object -Maximum).Maximum
	$maxOsNumber = if ($maxOsSupported -match '11') { '11.0' } else { '10.0' }

	[PSCustomObject]@{
		OSNumber  = $maxOsNumber
		ReleaseId = $maxReleaseId
	}
}

function Get-HPLatestBiosInfo {
	param(
		[Parameter(Mandatory = $true)]
		[pscustomobject]$ComputerDetails
	)

	$platform = $ComputerDetails.BaseBoardProduct
	$osInfo = Get-HPSupportedOsInfo -Platform $platform
	$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') { '64' } else { '32' }
	$cabUrl = ("https://hpia.hpcloud.hp.com/ref/{0}/{0}_{1}_{2}.{3}.cab" -f $platform, $arch, $osInfo.OSNumber, $osInfo.ReleaseId).ToLower()

	$workingPath = Get-TempWorkingPath
	$cabPath = Join-Path -Path $workingPath -ChildPath 'HPIA.cab'
	$xmlPath = Join-Path -Path $workingPath -ChildPath 'HPIA.xml'
	Invoke-DownloadFile -Url $cabUrl -Destination $cabPath
	Expand-CabFile -CabPath $cabPath -DestinationFile $xmlPath

	[xml]$xml = Get-Content -Path $xmlPath
	$biosUpdates = @($xml.ImagePal.Solutions.UpdateInfo | Where-Object { $_.Category -match 'bios' -or $_.Name -match 'bios' })
	if (-not $biosUpdates) {
		throw "No HP BIOS update was found for platform $platform"
	}

	$latest = $biosUpdates |
		Sort-Object -Property @(
			@{ Expression = { if ($_.ReleaseDate) { [datetime]$_.ReleaseDate } else { [datetime]::MinValue } }; Descending = $true },
			@{ Expression = { [string]$_.Version }; Descending = $true }
		) |
		Select-Object -First 1
	$currentVersion = [string]$ComputerDetails.SMBIOSBIOSVersion
	$latestVersion = [string]$latest.Version

	$currentComparable = ConvertTo-ComparableVersion -VersionString $currentVersion
	$latestComparable = ConvertTo-ComparableVersion -VersionString $latestVersion
	$isCurrent = $false

	if ($currentComparable -and $latestComparable) {
		$isCurrent = $currentComparable -ge $latestComparable
	}
	else {
		$isCurrent = ($currentVersion -eq $latestVersion)
	}

	return (Get-ResultObject -Manufacturer 'HP' -Model $ComputerDetails.Model -CurrentBiosVersion $currentVersion -LatestBiosVersion $latestVersion -CurrentBiosDate ([string]$ComputerDetails.ReleaseDate) -LatestBiosDate ([string]$latest.ReleaseDate) -IsCurrent $isCurrent -Source 'HP Image Assistant Reference Catalog')
}

function Get-BiosComplianceInfo {
	$computerDetails = Get-ComputerDetails
	$manufacturer = [string]$computerDetails.Manufacturer

	if ($manufacturer -match 'Dell') {
		return Get-DellLatestBiosInfo -ComputerDetails $computerDetails
	}

	if ($manufacturer -match 'HP|Hewlett-Packard') {
		return Get-HPLatestBiosInfo -ComputerDetails $computerDetails
	}

	if ($manufacturer -match 'Lenovo') {
		return Get-LenovoLatestBiosInfo -ComputerDetails $computerDetails
	}

	throw "Unsupported manufacturer $manufacturer. This script currently supports Dell, HP, and Lenovo."
}

try {
	$result = Get-BiosComplianceInfo

	if (-not $Quiet) {
		Write-Host 'BIOS Compliance Check' -ForegroundColor Cyan
		Write-Host '=====================' -ForegroundColor Cyan
		Write-Host "Manufacturer  $($result.Manufacturer)"
		Write-Host "Model         $($result.Model)"
		Write-Host "Current BIOS  $($result.CurrentBiosVersion)"
		Write-Host "Latest BIOS   $($result.LatestBiosVersion)"
		if ($result.LatestBiosDate) {
			Write-Host "Latest Date   $($result.LatestBiosDate)"
		}
		Write-Host "Source        $($result.Source)"
		Write-Host "Compliant     $($result.IsCurrent)"
	}

	if ($AsObject) {
		$result
	}
	else {
		$result.IsCurrent
	}
}
catch {
	Write-Error $_.Exception.Message
	exit 1
}
