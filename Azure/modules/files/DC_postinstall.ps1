# Create Run Once Entry
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"

Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String
Set-ItemProperty $RegPath "DefaultUsername" -Value $AdminUser -type String
Set-ItemProperty $RegPath "DefaultPassword" -Value $AdminPassword -type String
Set-ItemProperty $RegPath "DefaultDomainName" -Value $DomainName -type String
Set-ItemProperty $RegPath "AutoLogonCount" -Value "2" -type DWord
Set-ItemProperty $RegROPath "!AD_Create" -Value ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\terraform\ADSetup.ps1")

Set-WinUserLanguageList -LanguageList en-GB -Force

#Allow Ping
New-NetFirewallRule -DisplayName "ICMP Allow incoming V4 echo request" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow

# Create POST RDS Setup Script
$RDScontents = @"
    Import-Module RemoteDesktop
    `$RdsServerName = (Get-CimInstance -ClassName Win32_ComputerSystem).Name
    `$Domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
    `$DomainName  = `$Domain.Split(".") | Select-Object -First 1
    New-RDSessionCollection -CollectionName "#{SupplierName}# RDS" -SessionHost @("`$RdsServerName.`$Domain") -CollectionDescription "Session collection for #{SupplierName}# Application." -ConnectionBroker "`$RdsServerName.`$Domain"
    Set-RDSessionCollectionConfiguration -CollectionName "#{SupplierName}# RDS" -UserGroup "`$DomainName\#{SupplierName}#_admin","`$DomainName\#{SupplierName}#_users"
    # Quoted this line out for now, so i can see the output and manually test the license activation of RDS box
    # Remove-Item -Path "C:\terraform\RDS_Setup.ps1" -Force
"@

$RDScontents | Out-File -FilePath "C:\terraform\RDS_Setup.ps1"

# Create Post Domain Install Commands
$contents = @"
    `$timeStart = get-date
    "`$timeStart - AD Setup Post Reboot Started" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append
    Add-DnsServerPrimaryZone -NetworkID $ReverseLookupZone -ReplicationScope Forest
    "Add Dns Zone" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    # Create A Records 
    `$DomainName = (Get-ADDomain).Name
    Add-DnsServerResourceRecordA -Name "PhTestApp" -ZoneName "`$DomainName.local" -AllowUpdateAny -IPv4Address $PhTestAppIpAddress -TimeToLive 01:00:00
    Add-DnsServerResourceRecordA -Name "PhTestDB" -ZoneName "`$DomainName.local" -AllowUpdateAny -IPv4Address $PhTestDbIpAddress -TimeToLive 01:00:00
    Add-DnsServerResourceRecordA -Name "PhTestWeb" -ZoneName "`$DomainName.local" -AllowUpdateAny -IPv4Address $PhTestWebIpAddress -TimeToLive 01:00:00
    "Add A Records" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    If (`$env:COMPUTERNAME -like "*Live*") {
        Add-DnsServerResourceRecordA -Name "PhLiveApp" -ZoneName "`$DomainName.local" -AllowUpdateAny -IPv4Address $PhLiveAppIpAddress -TimeToLive 01:00:00
        Add-DnsServerResourceRecordA -Name "PhLiveDB" -ZoneName "`$DomainName.local" -AllowUpdateAny -IPv4Address $PhLiveDbIpAddress -TimeToLive 01:00:00
        Add-DnsServerResourceRecordA -Name "PhLiveWeb" -ZoneName "`$DomainName.local" -AllowUpdateAny -IPv4Address $PhLiveWebIpAddress -TimeToLive 01:00:00
    }
    
    # Creates the AD structure    
    New-ADOrganizationalUnit -Name #{SupplierName}#
    New-ADOrganizationalUnit -Name Admin -Path "OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    New-ADOrganizationalUnit -Name `$DomainName -Path "OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    New-ADOrganizationalUnit -Name Leavers -Path "OU=`$DomainName,OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    New-ADOrganizationalUnit -Name #{SupplierName}# -Path "OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    New-ADOrganizationalUnit -Name Leavers -Path "OU=#{SupplierName}#,OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    "Create AD Structure" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    # Create AD Groups
    New-ADGroup -Name "#{SupplierName}#_admin" -SamAccountName #{SupplierName}#_admin -GroupCategory Security -GroupScope Global -DisplayName "#{SupplierName}#_admin" -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    New-ADGroup -Name "#{SupplierName}#_users" -SamAccountName #{SupplierName}#_users -GroupCategory Security -GroupScope Global -DisplayName "#{SupplierName}#_users" -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    New-ADGroup -Name "#{SupplierName}#_web_test" -SamAccountName #{SupplierName}#_web_test -GroupCategory Security -GroupScope Global -DisplayName "#{SupplierName}#_web_test" -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    New-ADGroup -Name "#{SupplierName}#_web_live" -SamAccountName #{SupplierName}#_web_live -GroupCategory Security -GroupScope Global -DisplayName "#{SupplierName}#_web_live" -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local"
    "Create AD Groups" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    # Create Users
    New-Aduser -Name '#{SupplierName}#' -SamAccountName '#{SupplierName}#' -UserPrincipalName "#{SupplierName}#@`$DomainName.local" -Givenname '#{SupplierName}#' -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local" -PasswordNeverExpires `$true -AccountPassword (ConvertTo-SecureString "#{AD_User_Password}#" -AsPlainText -Force) -Enabled `$True
    New-Aduser -Name '#{SupplierName}#.Support' -SamAccountName '#{SupplierName}#.Support' -UserPrincipalName "#{SupplierName}#.support@`$DomainName.local" -Givenname '#{SupplierName}#' -Surname 'Support' -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local" -PasswordNeverExpires `$true -AccountPassword (ConvertTo-SecureString "#{AD_Support_User_Password}#" -AsPlainText -Force) -Enabled `$True
    New-Aduser -Name 'Sqlserveragentservice' -SamAccountName 'Sqlserveragentsvc' -UserPrincipalName "Sqlserveragentsvc@`$DomainName.local" -Givenname 'SQL Server' -Surname 'Agent Service' -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local" -PasswordNeverExpires `$true -AccountPassword (ConvertTo-SecureString "#{AD_SqlServerAgentService_Password}#" -AsPlainText -Force) -Enabled `$True
    New-Aduser -Name 'Sqlserverservice' -SamAccountName 'Sqlserverservice' -UserPrincipalName "Sqlserverservice@`$DomainName.local" -Givenname 'SQL Server' -Surname 'Service' -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local" -PasswordNeverExpires `$true -AccountPassword (ConvertTo-SecureString "#{AD_SqlServerService_Password}#" -AsPlainText -Force) -Enabled `$True
    New-Aduser -Name 'svc_#{SupplierName}#_api_LIVE' -SamAccountName 'svc_ph_api_LIVE' -UserPrincipalName "svc_#{SupplierName}#_api_LIVE@`$DomainName.local" -Givenname '#{SupplierName}# LIVE' -Surname 'API Service' -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local" -PasswordNeverExpires `$true -AccountPassword (ConvertTo-SecureString "#{AD_Svc_Api_LIVE_Password}#" -AsPlainText -Force) -Enabled `$True
    New-Aduser -Name 'svc_#{SupplierName}#_api_UAT' -SamAccountName 'svc_ph_api_UAT' -UserPrincipalName "svc_#{SupplierName}#_api_UAT@`$DomainName.local" -Givenname '#{SupplierName}# UAT' -Surname 'API Service' -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local" -PasswordNeverExpires `$true -AccountPassword (ConvertTo-SecureString "#{AD_Svc_Api_UAT_Password}#" -AsPlainText -Force) -Enabled `$True
    New-Aduser -Name 'svc_#{SupplierName}#_api_PREPROD' -SamAccountName 'svc_ph_api_PREPROD' -UserPrincipalName "svc_#{SupplierName}#_api_PREPROD@`$DomainName.local" -Givenname '#{SupplierName}# PREPROD' -Surname 'API Service' -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local" -PasswordNeverExpires `$true -AccountPassword (ConvertTo-SecureString "#{AD_Svc_Api_PREPROD_Password}#" -AsPlainText -Force) -Enabled `$True
    New-Aduser -Name 'svc_#{SupplierName}#_api_STAGING' -SamAccountName 'svc_ph_api_STAGING' -UserPrincipalName "svc_#{SupplierName}#_api_STAGING@`$DomainName.local" -Givenname '#{SupplierName}# STAGING' -Surname 'API Service' -Path "OU=Admin,OU=#{SupplierName}#,DC=`$DomainName,DC=local" -PasswordNeverExpires `$true -AccountPassword (ConvertTo-SecureString "#{AD_Svc_Api_STAGING_Password}#" -AsPlainText -Force) -Enabled `$True
    "Create AD Users" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    # Add users to Groups
    Add-ADGroupMember -Identity #{SupplierName}#_admin -Members #{SupplierName}#, #{SupplierName}#.support
    Add-ADGroupMember -Identity #{SupplierName}#_web_test -Members svc_ph_api_PREPROD, svc_ph_api_STAGING, svc_ph_api_UAT
    Add-ADGroupMember -Identity #{SupplierName}#_web_live -Members svc_ph_api_LIVE
    "Add AD Users To Groups" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

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
    
    `$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    `$RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
            
    Set-ItemProperty `$RegPath "AutoAdminLogon" -Value "1" -type String
    Set-ItemProperty `$RegPath "DefaultUsername" -Value $AdminUser -type String
    Set-ItemProperty `$RegPath "DefaultPassword" -Value $AdminPassword -type String
    Set-ItemProperty `$RegPath "DefaultDomainName" -Value $DomainName -type String
    Set-ItemProperty `$RegPath "AutoLogonCount" -Value "2" -type DWord
    Set-ItemProperty `$RegROPath "!1_DC_Post_Setup" -Value ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\terraform\DCPostInstall.ps1")
    Set-ItemProperty `$RegROPath "!2_DC_Post_Setup_2nd_Run" -Value ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\terraform\DCPostInstall.ps1")

    `$timeFinish = get-date
    "`$timeFinish - AD Setup Post Reboot Fininshed" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

   # Remove-Item -Path "C:\terraform\postinstall.ps1" -Force 
   # Quoted this line out for now, so i can see the output and manually test the license activation of RDS box
   # Remove-Item -Path "C:\terraform\ADSetup.ps1" -Force
   start-sleep -seconds 200
   Restart-Computer
"@

$contents | Out-File -FilePath "C:\terraform\ADSetup.ps1"

$DcPostInstall2 = @"
    # Setup RDS Server Roles
    `$RdsServerName = (Get-ADComputer -Filter 'Name -like "*RDS*"').DNSHostName
    `$AppServerName = (Get-ADComputer -Filter 'Name -like "*QA-APP*" -or Name -like "*PROD-APP*"').DNSHostName

    do {
    `$TestRdsConnection = Test-Connection -ComputerName `$RdsServerName -Count 1 -Quiet
    "Testing RDS Connection" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append
    } while (`$TestRdsConnection -eq `$false)

       do {
    `$TestAppServerConnection = Test-Connection -ComputerName `$AppServerName -Count 1 -Quiet
    "Testing App Server Connection" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append
    } while (`$TestAppServerConnection -eq `$false)

    # Setup RDS Server Roles
    Import-Module RemoteDesktop
    "RDS ServerName: `$RdsServerName" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append
    "RDS Roles Started" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    New-RDSessionDeployment -ConnectionBroker `$RdsServerName -SessionHost `$RdsServerName -WebAccessServer `$RdsServerName
    "RDS Session Created" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    # Licensing server 
    Add-RDServer -Server `$AppServerName -Role RDS-LICENSING -ConnectionBroker `$RdsServerName
    Set-RDLicenseConfiguration -LicenseServer `$AppServerName -Mode PerUser -ConnectionBroker `$RdsServerName -Force
    "Activate RDS Server" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    # Activate License Server 
    `$AppServerHostName = (Get-ADComputer -Filter 'Name -like "*QA-APP*" -or Name -like "*PROD-APP*"').Name
    `$licenseServer = `$AppServerHostName
    `$companyInformation = @{}
    `$companyInformation.FirstName="#{SupplierName}#"
    `$companyInformation.LastName="Software"
    `$companyInformation.Company="#{SupplierName}#"
    `$companyInformation.CountryRegion="United Kingdom"
    "Starting license Server activation" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    function Initialize-LicenseServer(`$licServer, `$companyInfo)
    {
        `$licServerResult = @{}
        `$licServerResult.LicenseServerActivated = `$Null

        `$wmiClass = ([wmiclass]"\\`$(`$licServer)\root\cimv2:Win32_TSLicenseServer")

        `$wmiTSLicenseObject = Get-WMIObject Win32_TSLicenseServer -computername `$licServer
        `$wmiTSLicenseObject.FirstName=`$companyInfo.FirstName
        `$wmiTSLicenseObject.LastName=`$companyInfo.LastName
        `$wmiTSLicenseObject.Company=`$companyInfo.Company
        `$wmiTSLicenseObject.CountryRegion=`$companyInfo.CountryRegion
        `$wmiTSLicenseObject.Put()

        `$wmiClass.ActivateServerAutomatic()

        `$licServerResult.LicenseServerActivated = `$wmiClass.GetActivationStatus().ActivationStatus
        "Activation Status: `$(`$licServerResult.LicenseServerActivated) (0 = Activated, 1 = Not Activated)" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append
    }

    Initialize-LicenseServer `$licenseServer `$companyInformation
    "Finished Activation License Server" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    `$AppServerName = Get-ADComputer -Filter 'Name -like "*QA-APP*" -or Name -like "*PROD-APP*"'
    Add-ADGroupMember -Identity "Terminal Server License Servers" -Members `$(`$AppServerName.DistinguishedName)
    "Add RDS to License Group" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    `$agreementNumber = 1234567

    `$Argumentlist =@(
    4, # AgreementType
    9999, # LicenseCount
    1, # ProductType
    5, # ProductVersion
    `$agreementNumber # AgreementNumber
    )

    Invoke-WmiMethod -Namespace "root/cimv2" -Class Win32_TSLicenseKeyPack -Name InstallAgreementLicenseKeyPack -ArgumentList `$Argumentlist -ComputerName `$licenseServer
    "Activate Licenses" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append

    # Create Run Once Entry on RDS Box to create the session collection
    "Create Run Once for next step" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append
    `$RDSContents = Get-Content -Path "C:\terraform\RDS_Setup.ps1"

    do {
        `$TestRdsConnection = Test-Connection -ComputerName `$RdsServerName -Count 1 -Quiet
        "Testing RDS Connection" | Out-File -FilePath "C:\terraform\ADSetup.log" -Append
        } while (`$TestRdsConnection -eq `$false)

        #Crete PS Session to RDS Server
    `$RdsSession = Get-PSSession | Where-Object { `$_.ComputerName -eq `$RdsServerName }
    if ( `$RdsSession -eq `$null ) {
        Write-Host "Creating PS Session to `$RdsServerName"
        `$RdsSession = New-PSSession -Computername `$RdsServerName
    }

    Invoke-Command -Session `$RdsSession -ScriptBlock { 
        try {
            `$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            `$RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"

            Set-ItemProperty `$RegPath "AutoAdminLogon" -Value "1" -type String
            Set-ItemProperty `$RegPath "DefaultUsername" -Value $AdminUser -type String
            Set-ItemProperty `$RegPath "DefaultPassword" -Value $AdminPassword -type String
            Set-ItemProperty `$RegPath "DefaultDomainName" -Value $DomainName -type String
            Set-ItemProperty `$RegPath "AutoLogonCount" -Value "2" -type DWord
            Set-ItemProperty `$RegROPath "!1_RDS_Setup" -Value ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\terraform\RDS_Setup.ps1")
            Set-ItemProperty `$RegROPath "!2_RDS_Setup" -Value ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\terraform\RDS_Setup.ps1")

            `$Using:RDScontents | Out-File -FilePath "C:\terraform\RDS_Setup.ps1"
            return "Success";
        }
        catch {
            return `$_
        }
    }
"@

$DcPostInstall2 | Out-File -FilePath "C:\terraform\DCPostInstall.ps1"