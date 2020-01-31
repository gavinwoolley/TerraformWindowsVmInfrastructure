# Configure the Microsoft Azure Provider
provider "azurerm" {
  version         = "~> 1.39"
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

terraform {
  backend "azurerm" {
    resource_group_name  = "#{backend_state_resource_group_name}#"
    storage_account_name = "#{backend_state_storage_account_name}#"
    container_name       = "#{backend_state_container_name}#"
    key                  = "#{backend_state_key}#"
  }
}

##########################################################
## Create QA - Resource Group, Network & Subnet
##########################################################
module "network" {
  source                  = "..\\..\\modules\\network"
  address_space           = var.address_space
  rdp_allowed_ip_prefixes = var.rdp_allowed_ip_prefixes
  dns_server              = ["${var.dc_private_ip_address}"]
  resource_group_name     = "${var.client_name}-${var.environment_name}-RG"
  location                = var.location
  subnet_prefix           = var.address_space
  client_name             = var.client_name
  environment             = var.environment_name
}

##########################################################
## Create QA - DC VM & AD Forest
##########################################################

module "active-directory" {
  source                        = "..\\..\\modules\\active-directory"
  resource_group_name           = module.network.out_resource_group_name
  location                      = var.location
  prefix                        = var.client_name
  subnet_id                     = module.network.subnet_subnet_id
  active_directory_domain       = "${var.client_name}.local"
  active_directory_netbios_name = var.client_name
  private_ip_address            = var.dc_private_ip_address
  admin_username                = var.admin_username
  admin_password                = var.domain_admin_password
  dsrm_password                 = var.domain_dsrm_password
  rdp_security_group_id         = module.network.out_rdp_security_group_id
  reverse_lookup_zone           = var.address_space
  client_name                   = var.client_name
  ph_test_app_ip_address        = var.uat_app_private_ip_address
  ph_live_app_ip_address        = ""
  ph_test_db_ip_address         = var.uat_sql_private_ip_address
  ph_live_db_ip_address         = ""
  ph_test_web_ip_address        = var.uat_web_private_ip_address
  ph_live_web_ip_address        = ""
  environment                   = var.environment_name
}

##########################################################
## Create QA - Servers & Join Domain
##########################################################

module "rds-server" {
    source                      = "..\\..\\modules\\rds-server"
    resource_group_name         = module.active-directory.out_resource_group_name
    location                    = module.active-directory.out_dc_location
    prefix                      = "${var.client_name}-${var.environment_name}"
    subnet_id                   = module.network.subnet_subnet_id
    active_directory_domain     = "${var.client_name}.local"
    admin_username              = var.admin_username
    admin_password              = var.domain_admin_password
    rds_private_ip_address      = var.uat_rds_private_ip_address
    rdp_security_group_id       = module.network.out_rdp_security_group_id
    client_name                 = var.client_name
    environment                 = var.environment_name
    }
    
module "app-server" {
    source                    = "..\\..\\modules\\app-server"
    resource_group_name       = module.active-directory.out_resource_group_name
    location                  = module.active-directory.out_dc_location
    prefix                    = "${var.client_name}-${var.environment_name}"
    subnet_id                 = module.network.subnet_subnet_id
    active_directory_domain   = "${var.client_name}.local"
    admin_username            = var.admin_username
    admin_password            = var.domain_admin_password
    app_private_ip_address    = var.uat_app_private_ip_address
    rdp_security_group_id     = module.network.out_rdp_security_group_id
    client_name               = var.client_name
    environment               = var.environment_name
    }

module "sql-vm" {
    source                    = "..\\..\\modules\\sql-vm"
    resource_group_name       = module.active-directory.out_resource_group_name
    location                  = module.active-directory.out_dc_location
    prefix                    = "${var.client_name}-${var.environment_name}"
    subnet_id                 = module.network.subnet_subnet_id
    active_directory_domain   = "${var.client_name}.local"
    admin_username            = var.admin_username
    admin_password            = var.domain_admin_password
    sql_private_ip_address    = var.uat_sql_private_ip_address
    rdp_security_group_id     = module.network.out_rdp_security_group_id
    client_name               = var.client_name
    sa_password               = var.sa_password
    sa_user                   = var.sa_user
    environment               = var.environment_name
     }

module "web-server" {
    source                    = "..\\..\\modules\\web-server"
    resource_group_name       = module.active-directory.out_resource_group_name
    location                  = module.active-directory.out_dc_location
    prefix                    = "${var.client_name}-${var.environment_name}"
    subnet_id                 = module.network.subnet_subnet_id
    active_directory_domain   = "${var.client_name}.local"
    admin_username            = var.admin_username
    admin_password            = var.domain_admin_password
    web_private_ip_address    = var.uat_web_private_ip_address
    rdp_security_group_id     = module.network.out_rdp_security_group_id
    client_name               = var.client_name
    environment               = var.environment_name
    }