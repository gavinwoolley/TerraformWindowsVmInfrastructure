variable resource_group_name {}
variable location {}
variable address_space {}
variable client_name {}

variable dns_server {
       type = list
}

variable subnet_prefix {}
variable "environment" {}

variable "rdp_allowed_ip_prefixes" {
         type = list
}
