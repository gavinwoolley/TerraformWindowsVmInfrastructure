###################################################################################################
# Outputs
####################################################################################################

output "subnet_subnet_id" {
  value = "${azurerm_subnet.subnet.id}"
}

output "out_resource_group_name" {
  value = "${azurerm_resource_group.network.name}"
}

output "out_rdp_security_group_id" {
  value = "${azurerm_network_security_group.securitygroup.id}"
}