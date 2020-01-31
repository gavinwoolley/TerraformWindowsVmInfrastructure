locals {
  rdsvirtual_machine_name = "${var.prefix}-RDS"
  rdsvirtual_machine_fqdn = "${local.rdsvirtual_machine_name}.${var.active_directory_domain}"
  rdscustom_data_params   = "Param($DomainName = \"${var.active_directory_domain}\", $AdminPassword = \"${var.admin_password}\", $AdminUser = \"${var.admin_username}\")"
  rdscustom_data_content  = "${local.rdscustom_data_params} ${file("${path.cwd}/../../modules/files/RDS_postinstall.ps1")}"
}

resource "azurerm_availability_set" "rdsavailabilityset" {
  name                         = "${var.prefix}-RDS-AvailabilitySet"
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

resource "azurerm_virtual_machine" "rds-server" {
  name                          = local.rdsvirtual_machine_name
  location                      = var.location
  availability_set_id           = azurerm_availability_set.rdsavailabilityset.id
  resource_group_name           = var.resource_group_name
  network_interface_ids         = [azurerm_network_interface.rdsprimary.id]
  vm_size                       = "Standard_B2s"
  delete_os_disk_on_termination = false

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.rdsvirtual_machine_name}-Disk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = local.rdsvirtual_machine_name
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = local.rdscustom_data_content
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
    name              = "${var.prefix}-RDS-Data-Disk1"
    disk_size_gb      = "50"
    caching           = "ReadWrite"
    create_option     = "Empty"
    managed_disk_type = "Standard_LRS"
    lun               = "2"
  }

    tags = {
      environment = var.environment
      client = var.client_name
  }
  
  depends_on = [azurerm_network_interface.rdsprimary]
}
