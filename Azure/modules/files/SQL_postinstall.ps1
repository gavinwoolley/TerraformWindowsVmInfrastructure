# Create Run Once Entry
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"

Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String
Set-ItemProperty $RegPath "DefaultUsername" -Value $AdminUser -type String
Set-ItemProperty $RegPath "DefaultPassword" -Value $AdminPassword -type String
Set-ItemProperty $RegPath "DefaultDomainName" -Value $DomainName -type String
Set-ItemProperty $RegPath "AutoLogonCount" -Value "1" -type DWord
Set-ItemProperty $RegROPath "!SQL_Setup" -Value ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\terraform\Setup.ps1")

Set-WinUserLanguageList -LanguageList en-GB -Force

#Allow Ping
New-NetFirewallRule -DisplayName "ICMP Allow incoming V4 echo request" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow

# Create Post Domain Install Commands
$contents = @"
`$timeStart = get-date
"`$timeStart - SQL Setup Post Reboot Started" | Out-File -FilePath "C:\terraform\Setup.log" -Append

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
"Installing Apps" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Add #{SupplierName}#_admin as Local Admin on servers - needs to wait for the user to be created first though
`$Domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
Add-LocalGroupMember -Group "Remote desktop users" -Member "`$Domain\#{SupplierName}#_admin"
"Add local group member" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Disable UAC
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force
"Disable UAC" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Enable Back Connection Hosts Names
New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0 -Name "BackConnectionHostNames" -Value "PhLiveDB","PhTestDB" -PropertyType multistring
"Enable Back Connection Names" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Config Disks
"Started Disk Init" | Out-File -FilePath "C:\terraform\Setup.log" -Append

`$diskConfigs = @(
    @{ LUN = 2; DriveLabel = "Data"; DriveLetter = "F" }
    @{ LUN = 3; DriveLabel = "Logs"; DriveLetter = "G" }
    @{ LUN = 4; DriveLabel = "TempDb"; DriveLetter = "I" }
    @{ LUN = 5; DriveLabel = "Backup"; DriveLetter = "H" }
)

ForEach (`$Config in `$diskConfigs) {
    Initialize-Disk -Number `$config.Lun -PartitionStyle MBR -PassThru |
    New-Partition -DriveLetter `$Config.DriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel `$Config.DriveLabel -Confirm:`$false -Force
}
"Fininshed Disk Init" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Create Folder Structure
New-Item F:\MSSQL\Data -itemtype directory
New-Item G:\MSSQL\Logs -itemtype directory
New-Item H:\MSSQL\Backups -itemtype directory
New-Item I:\MSSQL\TempDB -itemtype directory 
"Create Folder Structure" | Out-File -FilePath "C:\terraform\Setup.log" -Append

`$folderpath = "C:\terraform"
`$inifile = "`$folderpath\ConfigurationFile.ini"
`$SQLsource = "C:\SQLServerFull"

# SQL memory
`$SqlMemMin = 4096
`$SqlMemMax = 4096

# Configure Firewall settings for SQL
"Configuring SQL Server Firewall settings" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Enable SQL Server Ports
New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action allow
New-NetFirewallRule -DisplayName "SQL Admin Connection" -Direction Inbound -Protocol TCP -LocalPort 1434 -Action allow
New-NetFirewallRule -DisplayName "SQL Database Management" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action allow
New-NetFirewallRule -DisplayName "SQL Service Broker" -Direction Inbound -Protocol TCP -LocalPort 4022 -Action allow
New-NetFirewallRule -DisplayName "SQL Debugger/RPC" -Direction Inbound -Protocol TCP -LocalPort 135 -Action allow

"Start SQL Installer" | Out-File -FilePath "C:\terraform\Setup.log" -Append
Start-Sleep -Seconds 60

# Start the SQL installer
Try {
    if (Test-Path `$SQLsource) {
        Write-Host "About to install SQL Server 2017..." -nonewline
        `$fileExe = "`$SQLsource\setup.exe"
        `$CONFIGURATIONFILE = "`$folderpath\ConfigurationFile.ini"
        & `$fileExe  /CONFIGURATIONFILE=`$CONFIGURATIONFILE
        Write-Host "Done!" 
    }
    else {
        write-host "Could not find the media for SQL Server 2017..."
        break
    }
}
catch {
    write-host "Something went wrong with the installation of SQL Server, aborting."
    break
}

"Finish SQL Installer" | Out-File -FilePath "C:\terraform\Setup.log" -Append

Start-Sleep -Seconds 120

# Configure SQL memory
"Start SQL Memory Config" | Out-File -FilePath "C:\terraform\Setup.log" -Append

`$DomainName = `$Domain.Split(".") | select -First 1

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
`$SQLSettings = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "localhost"
`$SQLSettings.ConnectionContext.LoginSecure = `$false
`$SQLSettings.ConnectionContext.set_Login("saadminuser")
`$SQLSettings.ConnectionContext.set_Password("SAPassword123$!")
`$SQLSettings.ConnectionContext.Connect()
`$SQLSettings.Configuration.MinServerMemory.ConfigValue = `$SQLMemMin
`$SQLSettings.Configuration.MaxServerMemory.ConfigValue = `$SQLMemMax
`$SQLSettings.Configuration.Alter()

"Finish SQL Installer Memory Config" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Configure SQL Logins
`$computer = `$env:computername

`$SqlServerServiceUser = "`$DomainName\Sqlserverservice"
`$SqlServerServicePassword = "#{AD_SqlServerService_Password}#"

`$SqlAgentServiceUser = "`$DomainName\Sqlserveragentsvc"
`$SqlAgentServicePassword = "#{AD_SqlServerAgentService_Password}#"

"Start SQL Logins Config" | Out-File -FilePath "C:\terraform\Setup.log" -Append
`$Login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList `$SQLSettings, "`$DomainName\#{SupplierName}#_admin"
`$Login.LoginType = 'WindowsGroup'
`$login.Create('')
`$login.AddToRole('sysadmin')
`$Login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList `$SQLSettings, "`$DomainName\Domain Admins"
`$Login.LoginType = 'WindowsUser'
`$login.Create('')
`$login.AddToRole('sysadmin')
`$Login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList `$SQLSettings, "`$DomainName\#{SupplierName}#Admin"
`$Login.LoginType = 'WindowsUser'
`$login.Create('')
`$login.AddToRole('sysadmin')
`$Login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList `$SQLSettings, "`$SqlServerServiceUser"
`$Login.LoginType = 'WindowsUser'
`$login.Create('')
`$login.AddToRole('sysadmin')
`$Login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList `$SQLSettings, "`$SqlAgentServiceUser"
`$Login.LoginType = 'WindowsUser'
`$login.Create('')
`$login.AddToRole('sysadmin')

# Configure SQL Service Accounts

[void][reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
[void][reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")
`$wmi = New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer") `$computer
`$wmi.Services | Select Name, DisplayName, Type, StartMode, ServiceState, ServiceAccount | ft -auto
`$sqlserver = `$wmi.Services | where {`$_.Type -eq "SqlServer"}
`$sqlserver.SetServiceAccount(`$SqlServerServiceUser, `$SqlServerServicePassword)
`$sqlagent = `$wmi.Services | where {`$_.Type -eq "SqlAgent"}
`$sqlagent.SetServiceAccount(`$SqlAgentServiceUser, `$SqlAgentServicePassword)
"Finish SQL Logins Config" | Out-File -FilePath "C:\terraform\Setup.log" -Append

`$timeFinish = get-date
"`$timeFinish - SQL Setup Post Reboot Finished" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Cleanup script
#Remove-Item -Path "C:\terraform\postinstall.ps1" -Force 
#Remove-Item -Path "C:\terraform\Setup.ps1" -Force

Start-Sleep -Seconds 100
Restart-Computer
"@

$contents | Out-File -FilePath "C:\terraform\Setup.ps1"

# Configurationfile.ini Settings
$ACTION = "Install"
$QUIET = "True"
$FEATURES = "SNAC_SDK"
$INSTANCENAME = "MSSQLSERVER"
$IAcceptSQLServerLicenseTerms = "True"

$conffile = @"
[OPTIONS]
Action="$ACTION"
Quiet="$Quiet"
Features="$FEATURES"
InstanceName="$INSTANCENAME"
IAcceptSQLServerLicenseTerms="$IAcceptSQLServerLicenseTerms"
"@

$conffile | Out-File -FilePath "C:\terraform\ConfigurationFile.ini"