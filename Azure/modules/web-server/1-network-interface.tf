resource "azurerm_public_ip" "web-external" {
  name                         = "${var.prefix}-WEB-External"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  idle_timeout_in_minutes      = 30

      tags = {
      environment = var.environment
      client = var.client_name
  }

}

resource "azurerm_network_interface" "webprimary" {
  name                      = "${var.prefix}-WEB-Primary"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  internal_dns_name_label   = local.webvirtual_machine_name
  network_security_group_id = var.rdp_security_group_id

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "static"
    private_ip_address            = var.web_private_ip_address
    public_ip_address_id          = azurerm_public_ip.web-external.id
  }
  
      tags = {
      environment = var.environment
      client = var.client_name
  }
  depends_on = [var.rdp_security_group_id]
}
