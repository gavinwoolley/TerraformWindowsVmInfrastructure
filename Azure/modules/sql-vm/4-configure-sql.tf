resource "azurerm_virtual_machine_extension" "sql-config" {
  name                   = "SqlIaasExtension"
  location               = azurerm_virtual_machine.sql.location
  resource_group_name    = var.resource_group_name
  virtual_machine_name   = azurerm_virtual_machine.sql.name
  publisher              = "Microsoft.SqlServer.Management"
  type                   = "SqlIaaSAgent"
  type_handler_version   = "2.0"

  settings = <<SETTINGS
{
    "AutoTelemetrySettings": {
        "Region": "westeurope"

    },
    "sqlManagement": "Full",
    "AutoPatchingSettings": {
        "PatchCategory": "WindowsMandatoryUpdates",
        "Enable": false
    },
    "KeyVaultCredentialSettings": {
        "Enable": false,
        "CredentialName": ""
    },
    "ServerConfigurationsManagementSettings": {
        "sqlConnectivityUpdateSettings": {
            "ConnectivityType": "Private",
            "Port": "1433"
        },
        "sqlWorkloadTypeUpdateSettings": {
            "sqlWorkloadType": "GENERAL"
        },
        "AdditionalFeaturesServerConfigurations": {
            "IsRServicesEnabled": "false"
        },
          "sqlStorageUpdateSettings": {
          "DiskCount": "3",
          "NumberOfColumns": "3",
          "StartingDeviceID": "2",
          "DiskConfigurationType": "NEW"
      }
    },
    "storageConfigurationSettings": {
        "DiskConfigurationType": "NEW",
        "StorageWorkloadType": "OLTP",
        "sqlDataSettings": {
            "luns": "2",
            "DefaultFilePath": "F:\\MSsql\\Data"
        },
        "sqlLogSettings": {
            "luns": "3",
            "DefaultFilePath": "G:\\MSsql\\Logs"
        },
        "sqlTempDbSettings": {
            "luns": "5",
            "DefaultFilePath": "I:\\MSsql\\TempDB"
        }
    }
}
SETTINGS

 protected_settings = <<PROTECTED_SETTINGS
    {
        "SQLAuthUpdateUserName": "${var.sa_user}",
        "SQLAuthUpdatePassword": "${var.sa_password}"
    }
   PROTECTED_SETTINGS

  depends_on = [azurerm_virtual_machine_extension.join-domain]
}
