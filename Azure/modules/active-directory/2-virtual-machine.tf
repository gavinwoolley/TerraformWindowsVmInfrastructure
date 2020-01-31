locals {
  virtual_machine_name = "${var.prefix}-${var.environment}-DC"
  virtual_machine_fqdn = "${local.virtual_machine_name}.${var.active_directory_domain}"
  custom_data_params   = "Param($DomainName = \"${var.active_directory_domain}\", $AdminPassword = \"${var.admin_password}\", $AdminUser = \"${var.admin_username}\", $ReverseLookupZone = \"${var.reverse_lookup_zone}\", $RemoteHostName = \"${local.virtual_machine_fqdn}\", $ComputerName = \"${local.virtual_machine_name}\", $PhTestAppIpAddress = \"${var.ph_test_app_ip_address}\", $PhLiveAppIpAddress = \"${var.ph_live_app_ip_address}\", $PhTestDbIpAddress = \"${var.ph_test_db_ip_address}\", $PhLiveDbIpAddress = \"${var.ph_live_db_ip_address}\", $PhTestWebIpAddress = \"${var.ph_test_web_ip_address}\", $PhLiveWebIpAddress = \"${var.ph_live_web_ip_address}\")"
  custom_data_content  = "${local.custom_data_params} ${file("${path.cwd}/../../modules/files/DC_postinstall.ps1")}"
}

resource "azurerm_availability_set" "dcavailabilityset" {
  name                         = "${var.prefix}-DC-AvailabilitySet"
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

resource "azurerm_virtual_machine" "domain-controller" {
  name                          = local.virtual_machine_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  availability_set_id           = azurerm_availability_set.dcavailabilityset.id
  network_interface_ids         = [azurerm_network_interface.primary.id]
  vm_size                       = "Standard_B2s"
  delete_os_disk_on_termination = false

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.virtual_machine_name}-Disk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = local.virtual_machine_name
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = local.custom_data_content
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
        tags = {
        environment = var.environment
        client = var.client_name
    }
}
