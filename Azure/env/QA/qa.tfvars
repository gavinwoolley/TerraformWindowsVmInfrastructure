#################################################################
#  Variables
#################################################################

# Azure Provider login info
subscription_id = "#{subscription_id}#"
client_id = "#{client_id}#"
client_secret = "#{client_secret}#"
tenant_id = "#{tenant_id}#"

# Generic info
environment_name = "QA"
client_name = "#{ClientName}#"
location = "West Europe"

# The following are reserved by Azure
# x.x.x.0: Network address
# x.x.x.1: Reserved by Azure for the default gateway
# x.x.x.2, x.x.x.3: Reserved by Azure to map the Azure DNS IPs to the VNet space

# Network
address_space = "10.174.0.0/24"
rdp_allowed_ip_prefixes = #{Public_RDP_Allowed_IP_Addresses}# # Example ["1.1.1.1","2.2.2.2"]

# Active Directory & Domain Controller
dc_private_ip_address = "10.174.0.4"
admin_username = "#{SupplierName}#Admin"
domain_admin_password = "#{domain_admin_password}#"
domain_dsrm_password = "#{domain_dsrm_password}#"

## App Server ##
uat_app_private_ip_address = "10.174.0.5"

## SQL DB Server ##
sa_password = "#{sa_password}#"
sa_user = "saadminuser"

uat_sql_private_ip_address = "10.174.0.6"

## RDS Server ##
uat_rds_private_ip_address = "10.174.0.7"

## WEB Servers ##
uat_web_private_ip_address = "10.174.0.8"

