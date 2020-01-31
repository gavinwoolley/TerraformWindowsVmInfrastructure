#################################################################
#   Variables
#################################################################

# Provider info
variable subscription_id {}

variable client_id {}
variable client_secret {}
variable tenant_id {}

# Generic info
variable location {}
variable client_name {}

# Network
variable address_space {}
variable "rdp_allowed_ip_prefixes" {
         type = list
}
#variable prefix {}
variable dc_private_ip_address {}
variable admin_username {}
variable domain_admin_password {}
variable domain_dsrm_password {}

## App Server ##
variable uat_app_private_ip_address {}
variable prod_app_private_ip_address {}

## SQL DB Server ##
variable "sa_password" {}
variable "sa_user" {}

variable uat_sql_private_ip_address {}
variable prod_sql_private_ip_address {}

## RDS Server ##
variable prod_rds_private_ip_address {}

## WEB Server ##
variable uat_web_private_ip_address {}
variable prod_web_private_ip_address {}