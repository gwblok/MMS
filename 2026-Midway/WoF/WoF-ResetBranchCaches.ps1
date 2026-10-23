$serials = (Get-CimInstance -Namespace root/StifleR -ClassName ClientsIdentifiers).SerialNumber | Where-Object {$_.Length -eq 10}
$computerNames = foreach($serial in $serials){"PC-$serial"}
#$computerNames = "PC-3KTTA50931"
#$computerNames = "PC-4LTTA15625"
$computerNames | ForEach-Object -Parallel {
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
            #Clear Branch Cache
            Clear-BCCache -Force
        }
    }
}