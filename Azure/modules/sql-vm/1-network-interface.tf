resource "azurerm_public_ip" "sql-external" {
  name                         = "${var.prefix}-SQL-External"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  idle_timeout_in_minutes      = 30
  sku                          = "Standard"

      tags = {
      environment = var.environment
      client = var.client_name
  }
}

resource "azurerm_network_interface" "sqlprimary" {
  name                      = "${var.prefix}-SQL-Primary"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  internal_dns_name_label   = local.sqlvirtual_machine_name
  network_security_group_id = var.rdp_security_group_id

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "static"
    private_ip_address            = var.sql_private_ip_address
    public_ip_address_id          = azurerm_public_ip.sql-external.id
  }
      tags = {
      environment = var.environment
      client = var.client_name
  }
    depends_on = [var.rdp_security_group_id]
}