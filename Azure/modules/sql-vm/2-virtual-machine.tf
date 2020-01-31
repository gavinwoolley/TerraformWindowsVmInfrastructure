locals {
  sqlvirtual_machine_name = "${var.prefix}-SQL"
  sqlvirtual_machine_fqdn = "${local.sqlvirtual_machine_name}.${var.active_directory_domain}"
  sqlcustom_data_params   = "Param($DomainName = \"${var.active_directory_domain}\", $AdminPassword = \"${var.admin_password}\", $AdminUser = \"${var.admin_username}\")"
  sqlcustom_data_content  = "${local.sqlcustom_data_params} ${file("${path.cwd}/../../modules/files/SQL_postinstall.ps1")}"
}

resource "azurerm_availability_set" "sqlavailabilityset" {
  name                         = "${var.prefix}-SQL-AvailabilitySet"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  platform_fault_domain_count  = 3
  platform_update_domain_count = 5
  managed                      = true

      tags = {
      environment = var.environment
      client = var.client_name
  }
}

resource "azurerm_managed_disk" "sql_data_disk_1" {
  name                 = "${var.prefix}-SQL-Data-Disk1"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "50"

   tags = {
      environment = var.environment
      client = var.client_name
  }
}

resource "azurerm_managed_disk" "sql_log_disk_1" {
  name                 = "${var.prefix}-SQL-Log-Disk1"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "50"

   tags = {
      environment = var.environment
      client = var.client_name
  }
}

resource "azurerm_managed_disk" "sql_backup_disk_1" {
  name                 = "${var.prefix}-SQL-Backup-Disk1"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "100"

   tags = {
      environment = var.environment
      client = var.client_name
  }
}

resource "azurerm_managed_disk" "sql_tempdb_disk_1" {
  name                 = "${var.prefix}-SQL-TempDB-Disk1"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "50"

   tags = {
      environment = var.environment
      client = var.client_name
  }
}

resource "azurerm_virtual_machine" "sql" {
  name                          = local.sqlvirtual_machine_name
  location                      = var.location
  availability_set_id           = azurerm_availability_set.sqlavailabilityset.id
  resource_group_name           = var.resource_group_name
  network_interface_ids         = [azurerm_network_interface.sqlprimary.id]
  vm_size                       = "Standard_F4s_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2017-WS2019"
    sku       = "Standard"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.prefix}-SQL-OS-Disk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = local.sqlvirtual_machine_name
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = local.sqlcustom_data_content
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = false

    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
    }

    # Unattend config is to complete post installation setup steps..
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = file("${path.cwd}/../../modules/files/FirstLogonCommands.xml")
    }
  }

   storage_data_disk {
    name              = "${var.prefix}-SQL-Data-Disk1"
    caching           = "ReadOnly"
    create_option     = "Attach"
    managed_disk_id   = azurerm_managed_disk.sql_data_disk_1.id
    lun               = "2"
    disk_size_gb      = 50
  }

   storage_data_disk {
    name              = "${var.prefix}-SQL-Log-Disk1"
    caching           = "ReadOnly"
    create_option     = "attach"
    managed_disk_id   = azurerm_managed_disk.sql_log_disk_1.id
    lun               = "3"
    disk_size_gb      = 50
  }

   storage_data_disk {
    name              = "${var.prefix}-SQL-TempDB-Disk1"
    caching           = "ReadOnly"
    create_option     = "attach"
    managed_disk_id   = azurerm_managed_disk.sql_tempdb_disk_1.id
    lun               = "4"
    disk_size_gb      = 50
  }

   storage_data_disk {
    name              = "${var.prefix}-SQL-Backup-Disk1"
    caching           = "ReadOnly"
    create_option     = "attach"
    managed_disk_id   = azurerm_managed_disk.sql_backup_disk_1.id
    lun               = "5"
    disk_size_gb      = 100
  }

    tags = {
      environment = var.environment
      client = var.client_name
  }
  
  depends_on = [azurerm_network_interface.sqlprimary]
}
