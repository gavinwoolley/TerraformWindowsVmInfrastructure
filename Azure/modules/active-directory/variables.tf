variable "resource_group_name" {
  description = "The name of the Resource Group where the Domain Controllers resources will be created"
}

variable "location" {
  description = "The Azure Region in which the Resource Group exists"
}

variable "prefix" {
  description = "The Prefix used for the Domain Controller's resources"
}

variable "subnet_id" {
  description = "The Subnet ID which the Domain Controller's NIC should be created in"
}

variable "private_ip_address" {}

variable "active_directory_domain" {
  description = "The name of the Active Directory domain, for example `consoto.local`"
}

variable "active_directory_netbios_name" {
  description = "The netbios name of the Active Directory domain, for example `consoto`"
}

variable "admin_username" {
  description = "The username associated with the local administrator account on the virtual machine"
}

variable "admin_password" {
  description = "The password associated with the local administrator account on the virtual machine"
}

variable "dsrm_password" {
  description = "The password used for AD DSRM password"
}
variable rdp_security_group_id {}

variable "environment" {}

variable "client_name" {}

variable reverse_lookup_zone {}

variable ph_test_app_ip_address {}
variable ph_live_app_ip_address {
  default = null
}
variable ph_test_db_ip_address {}
variable ph_live_db_ip_address {
  default = null
}
variable ph_test_web_ip_address {}
variable ph_live_web_ip_address {
  default = null
}