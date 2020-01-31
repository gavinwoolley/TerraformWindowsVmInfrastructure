# Create Run Once Entry
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"

Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String
Set-ItemProperty $RegPath "DefaultUsername" -Value $AdminUser -type String
Set-ItemProperty $RegPath "DefaultPassword" -Value $AdminPassword -type String
Set-ItemProperty $RegPath "DefaultDomainName" -Value $DomainName -type String
Set-ItemProperty $RegPath "AutoLogonCount" -Value "1" -type DWord
Set-ItemProperty $RegROPath "AD_Create" -Value ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\terraform\Setup.ps1")

Set-WinUserLanguageList -LanguageList en-GB -Force

#Allow Ping
New-NetFirewallRule -DisplayName "ICMP Allow incoming V4 echo request" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow

# Create Post Domain Install Commands
$contents = @"
# Install Required Apps
function Install-Software {

    `$source = ("C:\terraform" + "\SW")
    `$packages = @(
        @{title = '7zip Extractor 19.00'; url = 'https://www.7-zip.org/a/7z1900-x64.msi'; Arguments = ' /qn'; Destination = `$source },
        @{title = 'Notepad++ 7.8.3'; url = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v7.8.3/npp.7.8.3.Installer.x64.exe'; Arguments = ' /Q /S'; Destination = `$source }
    )

    If (!(Test-Path -Path `$source)) {
        New-Item -Path `$source -ItemType directory 
    }
    
    foreach (`$package in `$packages) {
        `$packageName = `$package.title
        `$fileName = Split-Path `$package.url -Leaf
        `$destinationPath = `$package.Destination + "\" + `$fileName

        Write-Host "Downloading `$packageName"
        `$webClient = New-Object System.Net.WebClient
        `$webClient.DownloadFile(`$package.url, `$destinationPath)
    }

    foreach (`$package in `$packages) {
        `$packageName = `$package.title
        `$fileName = Split-Path `$package.url -Leaf
        `$destinationPath = `$package.Destination + "\" + `$fileName
        `$Arguments = `$package.Arguments
        Write-Output "Installing `$packageName"

        Invoke-Expression -Command "`$destinationPath `$Arguments"
    }   
}

Install-Software
"Installing Apps" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

# Add #{SupplierName}#_admin as Local Admin on servers - needs to wait for the user to be created first though
`$Domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
Add-LocalGroupMember -Group "Remote desktop users" -Member "`$Domain\#{SupplierName}#_admin"

# Disable UAC
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force

# Enable Back Connection Hosts Names
New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0 -Name "BackConnectionHostNames" -Value "PhLiveWeb","PhTestWeb" -PropertyType multistring

# Cleanup script
Remove-Item -Path "C:\terraform\postinstall.ps1" -Force 
Remove-Item -Path "C:\terraform\Setup.ps1" -Force

Restart-Computer

"@

$contents | Out-File -FilePath "C:\terraform\Setup.ps1"