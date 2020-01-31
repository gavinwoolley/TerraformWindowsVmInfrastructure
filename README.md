# Azure VM Infrastructure as Code

This project will enable you to create Azure infrastructure using Terraform.

There is also a `docker-compose.yml` file to create a Grafana, InfluxDb, Telegraf Monitoring solution. See [Docker / Grafana Readme.md File](Monitoring_Stack\README.md)

And a Powershell tool to monitor a windows process `Processing_Monitor\processingMonitoring.ps1`, which reports back to Geckoboard and sends an email notification.

## Getting Started

These instructions will get you a copy of the project up and running for development and testing purposes.

Bare in mind that anywhere you see this pattern in the code `#{subscription_id}#`. These are variable place holders, that are being replaced during the Azure DevOps Pipeline execution.

## Terraform-Templates

Terraform Templates to Deploy Client Infrastructure onto Azure

- Tested with Terraform 0.12.18

## Overview

This terraform module creates the following VM's, an Active Directory Domain and joins the VM's to it within one VNet with one subnet:

- DC - Server 2019 Primary Domain Controller holding FSMO roles, Static Public & Private IP Addresses

- SQL VM - Server 2019 - SQL 2017 & SSMS Installed and configured, Windows Server 2019, Static Public & Private IP Addresses, Joined to Domain

- RDS - Server 2019 RDS Roles, Static Public & Private IP Addresses, Joined to Domain

- APP - Server 2019 App Server, Static Public & Private IP Addresses, Joined to Domain, Shared Folder structure with AD permissions added

- WEB - Server 2019 Web Server, Static Public & Private IP Addresses, Joined to Domain

Includes an `live.tfvars` and `qa.tfvars` file, to allow this Infrastructure to be deployed throughout a pipeline to multiple clients and environments.

i.e:

- QA
- UAT
- PROD

QA has all the infrastructure components.

UAT and PROD has all the infrastructure components but share a vNet and DC.

## Notes

- This is intended to create a multi tier architecture joined to an Active Directory Domain. e.g.:
- There's no security rules configured on the network, so everything's open internally etc.
- Usernames / Passwords are in plaintext rather than using a secret store likeAzure Key Vault
- You can RDP to all servers over the public internet from defined allowed IPAddresses, rather than VPN or Bastion Host
- The numbering on the files within the modules below have no effect on which order the resources are created in - it's purely to make it easier to understand.

## Running this Example

Since I have replaced most values using variables in an Azure DevOps Pipeline, its quite tricky to now run this project locally. You would have to replace everything with this pattern `#{value}#`.

In order to run this solution, you need the following.

## PreRequisites

**Azure DevOps Subscription** - You can use the free tier. **(Just needs Repo and Pipelines)**

- You will need to import this repo and create a pipeline using either or both:
  - `azure-pipelines-infrastructure-QA.yml`
  - `azure-pipelines-infrastructure-LIVE.yml`

- You also need a variable group called **TerraformGlobalValues** with the following values populated:

```yaml
AD_SqlServerAgentService_Password: #{SecretPasswordValue}#
AD_SqlServerService_Password: #{SecretPasswordValue}#
AD_Support_User_Password: #{SecretPasswordValue}#
AD_Svc_Api_LIVE_Password: #{SecretPasswordValue}#
AD_Svc_Api_PREPROD_Password: #{SecretPasswordValue}#
AD_Svc_Api_STAGING_Password: #{SecretPasswordValue}#
AD_Svc_Api_UAT_Password: #{SecretPasswordValue}#
AD_User_Password: #{SecretPasswordValue}#
backend_state_container_name: #{ContainerName}#
backend_state_resource_group_name: #{StorageResourceGroupName}#
backend_state_storage_account_name: #{StorageContainerName}#
backend_state_key: #{StorageFileNameToCreate}#
client_id: #{ServicePrincipalAppId}#
client_secret: #{ServicePrincipalSecret}#
domain_admin_password: #{SecretPasswordValue}#
domain_dsrm_password: #{SecretPasswordValue}#
Public_RDP_Allowed_IP_Addresses: ["1.1.1.1","2.2.2.#{2"]}#
sa_password: #{SecretPasswordValue}#
subscription_id: #{AzureSubscriptionId}#
tenant_id: #{AzureTenantId}#
```

**Azure Portal Subscription** - A Free subscription only allows 4 x free VM CPU's. So you would need a full paid subscription, or cut out some VM's so the CPU count is 4 or less.

**Azure Storage Account** - Create a Storage Account to be used for Terraform Remote State file. Then update the variable group with the settings:

```yaml
backend_state_container_name: #{backend_state_container_name}#
backend_state_resource_group_name: #{backend_state_resource_group_name}#
backend_state_storage_account_name: #{backend_state_storage_account_name}#
backend_state_key: #{backend_state_key}#
```

**Credentials and Authentication**:

- An Azure Service Principal, with the proper role and permissions needs to be created prior to deploying workloads into Azure using terraform.

See: [Terraform Service Principal Docs](https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html) and [Microsoft Service Principal Docs](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)

- Once the service principal has been created on Azure, edit the **Variable Group** with the following fields (pertaining to the service principal):

```YML
subscription_id: #{subscription_id}#
client_id: #{client_id}#
client_secret: #{client_secret}#
tenant_id: #{tenant_id}#
```

**Azure DevOps Authentication**:

- An Azure DevOps Service Connection is also required.
  - Go to Project Settings, Service Connections.
  - Create a new **Azure Resource Manager** connection using the Service Principal manual selection and the same settings as above. Make sure they are marked as secrets.

Usage:

-------------------------------------------------------

You should now have an Azure DevOps account and Azure subscription with the required connection and authentication settings.

If you trigger either pipeline, it will create and test the infrastructure.

This will take around 25 minutes to provision - once completed you should see a resource group containing everything described above.

## Modules

This example makes use of 6 modules:

- [modules/active-directory](modules/active-directory)
  - This module creates an Active Directory Forest on a singleVirtual Machine
- [modules/network](modules/network)
  - This module creates the Network with 1 subnet.
  - In a Production environment there would be [NetworkSecurity Rules](https://www.terraform.io/docs/providersazurerm/r/network_security_rule.html) in effect which limited which ports can be used, however for the purposes of keeping this demonstration simple, these have been omitted.
- [modules/app-server](modules/app-server)
  - This module creates the App Server
- [modules/sql-vm](modules/sql-vm)
  - This module creates a SQL VM
- [modules/sql-vm](modules/web-server)
  - This module creates a Windows 2019 Server
- [modules/rds-server](modules/rds-server)
  - This module creates a RDS Windows 2019 Server

## Configuration

The VM Post installation configuration is handled by Powershell PostInstall Scripts, which are ran from the `RunOnce` registry key.

The scripts are located in `Azure\modules\files`

The DC Post Install Script:

- Set Keyboard Language en-GB
- Allow ICMP (Ping) through Local Firewall
- Creates DNS Reverse Lookup Zone
- Creates DNS A Records
- Creates an AD OU Structure, a number of users and groups.
- Installs 7Zip, Notepad++
- Then it targets the RDS and APP server's to install, configure and license an RDS Session Host and Collection

The SQL Post Install Script:

- Set Keyboard Language en-GB
- Allow ICMP (Ping) through Local Firewall
- Installs 7Zip, Notepad++
- Adds domain admin users to local Remote Desktop Group
- Disable UAC
- Enable Back Connection Host Names
- Configure 4 x additional Virtual Disks for Data, Logs, Backup, TempDb
- Opens SQL Local Firewall Ports
- Runs SQL installer with `Configuration.ini` file
- Configures SQL Memory - Max / Min
- Configures SQL Service Accounts
- Adds AD Users / Groups to SQL Server Logins

The WEB Post Install Script:

- Set Keyboard Language en-GB
- Allow ICMP (Ping) through Local Firewall
- Installs 7Zip, Notepad++
- Adds domain admin users to local Remote Desktop Group
- Disable UAC
- Enable Back Connection Host Names

The RDS Post Install Script:

- Set Keyboard Language en-GB
- Allow ICMP (Ping) through Local Firewall
- Installs 7Zip, Notepad++, Adobe Reader 19.021
- Adds domain admin users to local Remote Desktop Group
- Disable UAC
- Enable Back Connection Host Names

The APP Post Install Script:

- Set Keyboard Language en-GB
- Allow ICMP (Ping) through Local Firewall
- Installs 7Zip, Notepad++
- Adds domain admin users to local Remote Desktop Group
- Adds LocalMachine to Terminal Servers License Group
- Configure 1 x additional Virtual Disk for Data
- Disable UAC
- Enable Back Connection Host Names
- Creates folder structure
- Disables inheritance
- Sets Admins permissions
- Enable Symbolic links
- Create Shared Folder Structure and Apply Permissions

## Known Faults

### Pipeline Failed - State File Locked

Sometimes if the pipeline fails, the terraform state file could get stuck in a locked state. You will probably see an error like this.

```log
Error: Error locking state: Error acquiring the state lock: storage: service returned error: StatusCode=409, ErrorCode=LeaseAlreadyPresent, ErrorMessage=There is already a lease present.
````

You need to remove the lock from the Azure Blob in the Storage Account.
Browse to [Azure Portal](https://portal.azure.com/)
Find the Storage Account.

Open Storage Explorer, go to the BLOB container `terraform-state` browse the path `terraform-state/tf/TestClient/` there is a `QA` and `LIVE` Folder, each have the terraform state file contained.
If it is locked, there will be a small padlock icon next to the file `terraform.tfstate` right click on the file and select `Break Lease`.
This will break the lock, and allow the pipeline to run again.

### Pipeline Failed - Stuck on DC Install

If the pipeline fails on a stage like, joining machines to domain or configuring SQL. 

For some reason the DC installation has probably got stuck or crashed. Which in turn causes the other machines to fail joining the domain and fail configuring SQL permissions etc.
If this does happen. I have been deleting the resource group and resources for that **CLIENT / ENV** combination, then re-running the pipeline and it generally succeeds the second time.
