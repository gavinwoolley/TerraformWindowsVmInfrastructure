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
Add-LocalGroupMember "Terminal Server License Servers" -Member 'Network Service'

# Disable UAC
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force

# Enable Back Connection Hosts Names
New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa\MSV1_0 -Name "BackConnectionHostNames" -Value "PhLiveApp","PhTestApp" -PropertyType multistring


# Config Disks
"Started Disk Init" | Out-File -FilePath "C:\terraform\Setup.log" -Append

`$diskConfigs = @(
    @{ LUN = 2; DriveLabel = "Data"; DriveLetter = "F" }
)

ForEach (`$Config in `$diskConfigs) {
    Initialize-Disk -Number `$config.Lun -PartitionStyle MBR -PassThru |
    New-Partition -DriveLetter `$Config.DriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel `$Config.DriveLabel -Confirm:`$false -Force
}
"Fininshed Disk Init" | Out-File -FilePath "C:\terraform\Setup.log" -Append

If (`$env:COMPUTERNAME -like "*UAT*") {
    `$envs = "PH_UAT", "PH_PREPROD", "PH_STAGING"
}
If (`$env:COMPUTERNAME -like "*PROD*") {
    `$envs = "PH_LIVE"
}

`$location = "`$(`$diskConfigs.DriveLetter):"
`$PhRoot = "#{SupplierName}#"
`$PhApp = "PhApp"
`$PhWeb = 'PhWeb'

`$adminGroup = "#{SupplierName}#_admin"
`$usersGroup = "#{SupplierName}#_users"

#Disable Inheritance Function
Function DisableInheritance(`$path) {
    `$acl = Get-Acl `$path
    `$acl.SetAccessRuleProtection(`$true, `$false)
    `$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    `$acl.AddAccessRule(`$accessrule)
    `$acl | Set-Acl `$path 
}

#Function to add admin full control permissions back to folders with disabled inheritance
Function AdminPermissions(`$path) {
    `$acl = Get-Acl `$path
    `$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(`$Admingroup, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    `$AccessRule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("Domain Admins", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    `$AccessRule3 = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    `$acl.SetAccessRule(`$AccessRule)
    `$acl | Set-Acl `$path 
    `$acl.SetAccessRule(`$AccessRule2)
    `$acl | Set-Acl `$path
    `$acl.SetAccessRule(`$AccessRule3)
    `$acl | Set-Acl `$path  
}

#Function to add user Read permissions
Function UserRPermissions(`$path) {
    `$acl = Get-Acl `$path
    `$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(`$usersgroup, "Read", "ContainerInherit,ObjectInherit", "None", "Allow")
    `$acl.SetAccessRule(`$AccessRule)
    `$acl | Set-Acl `$path 
}

#Function to add user Write permissions
Function UserWPermissions(`$path) {
    `$acl = Get-Acl `$path
    `$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(`$usersgroup, "Write", "ContainerInherit,ObjectInherit", "None", "Allow")
    `$acl.SetAccessRule(`$AccessRule)
    `$acl | Set-Acl `$path 
}

#Create main directory
new-item -ItemType Directory -path `$location\`$PhRoot

#Create Release_Automation structure
new-item -ItemType Directory -path `$location\`$PhRoot\`$phapp\Release_Automation\releases\staging

#Create PhWeb
new-item -ItemType Directory -path `$location\`$PhRoot\`$phweb\Jenkins

#Enable Symbolic Links
fsutil behavior set SymlinkEvaluation R2R:1

#Apply User permissions to top directories
DisableInheritance -path "`$location\`$PhRoot"
UserWPermissions -path "`$location\`$PhRoot"
AdminPermissions -path "`$location\`$PhRoot"

#Disable Inheritance on non-environment folders
DisableInheritance -path "`$location\`$PhRoot\`$phapp\release_automation"
DisableInheritance -path "`$location\`$PhRoot\`$phweb"
AdminPermissions -path "`$location\`$PhRoot\`$phapp\release_automation"
AdminPermissions -path "`$location\`$PhRoot\`$phweb"

#Create non-environment shares
New-SMBshare -Name Release_Automation -Path `$location\`$PhRoot\`$phapp\Release_Automation -FullAccess `$adminGroup, "domain admins" 
New-SMBshare -Name PhWeb -Path `$location\`$PhRoot\`$phweb -FullAccess `$adminGroup, "domain admins"

foreach (`$environment in `$envs) {
    #Create Environment Structure 
    new-item -ItemType Directory -path `$location\`$PhRoot\`$phapp\`$environment\PhAdmin
    new-item -ItemType Directory -path `$location\`$PhRoot\`$phapp\`$environment\PhClient
    new-item -ItemType Directory -path `$location\`$PhRoot\`$phapp\`$environment\PhConfig\releases\1.100.0
    new-item -ItemType Directory -path `$location\`$PhRoot\`$phapp\`$environment\PhData

    #Create Symbolic Link 
    cmd.exe /c mklink /d `$location\`$PhRoot\`$phapp\`$environment\PhConfig\releases\latest `$location\`$phapp\`$environment\PhConfig\releases\1.100.0

    #Disable inheritance 
    DisableInheritance -path "`$location\`$PhRoot\`$phapp\`$environment\PhAdmin"

    #Apply admin user group to directories with disabled inheritance
    AdminPermissions -path "`$location\`$PhRoot\`$phapp\`$environment\PhAdmin"

    #Apply user write permissions to phdata folder
    UserWPermissions -path "`$location\`$PhRoot\`$phapp\`$environment\PhData"

    #Create Environment Shares
    New-SMBshare -Name `$Environment -Path `$location\`$phroot\`$phapp\`$environment -FullAccess `$adminGroup, "domain admins" -changeaccess `$usersGroup 
}

"Create Folder Structure" | Out-File -FilePath "C:\terraform\Setup.log" -Append

# Cleanup script
#Remove-Item -Path "C:\terraform\postinstall.ps1" -Force 
#Remove-Item -Path "C:\terraform\Setup.ps1" -Force

Restart-Computer

"@

$contents | Out-File -FilePath "C:\terraform\Setup.ps1"
