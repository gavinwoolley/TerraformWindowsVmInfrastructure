resource "azurerm_resource_group" "network" {
  name     = var.resource_group_name
  location = var.location

      tags = {
      environment = var.environment
      client = var.client_name
  }
     lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_network_security_group" "securitygroup" {
  name                = "${var.client_name}-${var.environment}-SecurityGroup"
  location            = var.location
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_resource_group.network]

      tags = {
      environment = var.environment
      client = var.client_name
  }
     lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_network_security_rule" "allow-rdp" {
  name                        = "Allow-RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = var.rdp_allowed_ip_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.securitygroup.name

    depends_on = [azurerm_network_security_group.securitygroup]

         lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_network_security_rule" "allow-winrm" {
  name                        = "Allow-WinRm"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5986"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.securitygroup.name

  depends_on = [azurerm_network_security_group.securitygroup]

       lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.client_name}-${var.environment}-vNet"
  address_space       = [var.address_space]
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_servers         = var.dns_server

  depends_on = [azurerm_resource_group.network]

      tags = {
      environment = var.environment
      client = var.client_name
  }
    lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.client_name}-${var.environment}-Subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefix       = var.subnet_prefix

  depends_on = [azurerm_virtual_network.main]

   lifecycle {
    ignore_changes = all
  }
}
