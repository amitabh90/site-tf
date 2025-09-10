// Global / naming variables
variable "environment" {
  type        = string
  description = "Deployment environment identifier (e.g. dev, staging, prod)."
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming Azure resources (e.g. 'site')."
  default     = "site"
}

// Azure subscription ID (parent scope for the resource group)
variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID to deploy into."
}

// Primary Azure region
variable "location" {
  type        = string
  description = "Azure region for the resource group and resources that inherit its location."
  default     = "eastus"
}

// Virtual Network & Subnets
variable "vnet_address_space" {
  type        = list(string)
  description = "Address space list for the virtual network."
}

variable "subnets" {
  description = "Map of subnet configurations keyed by logical name. name = actual Azure subnet resource name."
  type = map(object({
    name              = string
    address_prefix    = string
    service_endpoints = optional(list(string), [])
  }))
}

// Optional user supplied tags merged with mandatory tags
variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to merge with mandatory tags."
  default     = {}
}

// (Optional) Explicit CIDR for app subnet reused in NSG rules. If unset it will be inferred from subnets["app"].address_prefix
variable "app_subnet_cidr" {
  type        = string
  description = "CIDR of the application subnet, used in security rules. Overrides inferred value if set."
  default     = ""
}

# ---------------- Storage Variables ----------------
variable "storage_account_name" {
  type        = string
  description = "Explicit storage account name (leave blank to auto-generate). Must be 3-24 lowercase alphanumeric and globally unique."
  default     = ""
}

variable "storage_account_kind" {
  type        = string
  description = "Storage account kind."
  default     = "StorageV2"
}

variable "storage_account_sku" {
  type        = string
  description = "Storage account SKU tier."
  default     = "Standard_RAGRS"
}

variable "storage_access_tier" {
  type        = string
  description = "Default access tier for blob data."
  default     = "Hot"
}

variable "storage_large_file_shares_enabled" {
  type        = bool
  description = "Enable large file shares feature."
  default     = true
}

variable "storage_allow_blob_public_access" {
  type        = bool
  description = "Allow anonymous/public blob access (generally false for production)."
  default     = false
}

variable "storage_public_network_access" {
  type        = string
  description = "Public network access setting (Enabled or Disabled)."
  default     = "Enabled"
}

variable "storage_min_tls_version" {
  type        = string
  description = "Minimum TLS version enforced."
  default     = "TLS1_2"
}

variable "storage_allow_shared_key_access" {
  type        = bool
  description = "Allow Shared Key (classic access keys) authentication."
  default     = true
}

variable "storage_supports_https_traffic_only" {
  type        = bool
  description = "Force HTTPS only traffic."
  default     = true
}


locals {
  vnet_name = "${var.name_prefix}-vnet-${var.environment}"

  // Resource Group name pattern
  resource_group_name = "${var.name_prefix}-group-${var.environment}"

  // Monitoring Resource Group name pattern (separate RG for monitoring assets if desired)
  monitoring_resource_group_name = "${var.name_prefix}-groupmon-${var.environment}"

  // Derive NSG names per logical subnet key (front, app, database, etc.)
  nsg_names = {
    for k, v in var.subnets : k => "${var.name_prefix}-nsg-${k}-${var.environment}"
  }

  // Mandatory base tags
  base_tags = {
    environment = var.environment
  }

  merged_tags = merge(local.base_tags, var.extra_tags)

  // Convenience lookups
  app_subnet_cidr_effective = var.app_subnet_cidr != "" ? var.app_subnet_cidr : (try(var.subnets["app"].address_prefix, ""))

  // Derived storage account name when not explicitly set
  storage_account_name = var.storage_account_name != "" ? var.storage_account_name : lower(replace("${var.name_prefix}azstorage${var.environment}", "[^a-z0-9]", ""))

  # App Service Plan name (can override via var.app_service_plan_name to keep legacy/imported names)
  app_service_plan_name_effective      = var.app_service_plan_name != "" ? var.app_service_plan_name : "${var.name_prefix}-appserviceplan-${var.environment}"
  frontend_app_service_name_effective  = var.frontend_app_service_name != "" ? var.frontend_app_service_name : "${var.name_prefix}-frontendservice-${var.environment}"
  drupal_app_service_name_effective    = var.drupal_app_service_name != "" ? var.drupal_app_service_name : "${var.name_prefix}-drupalservice-${var.environment}"
  redis_enterprise_name_effective      = var.redis_enterprise_name != "" ? var.redis_enterprise_name : "${var.name_prefix}-rediscache-${var.environment}"
  mysql_flexible_server_name_effective = var.mysql_flexible_server_name != "" ? var.mysql_flexible_server_name : "${var.name_prefix}-mysqlserver-${var.environment}"
  frontdoor_profile_name_effective     = var.frontdoor_profile_name != "" ? var.frontdoor_profile_name : "${var.name_prefix}-frontdoor-${var.environment}"
  frontdoor_endpoint_name_effective    = var.frontdoor_endpoint_name != "" ? var.frontdoor_endpoint_name : "${var.name_prefix}-fde-${var.environment}"
}

#############################
# App Service Plan Variables
#############################
variable "app_service_plan_name" {
  type        = string
  description = "Explicit App Service Plan name (leave blank to auto-generate)."
  default     = ""
}

variable "app_service_plan_sku_name" {
  type        = string
  description = "SKU name for the App Service Plan (e.g. P0v3, B1, S1)."
  default     = "P0v3"
}

variable "app_service_plan_sku_tier" {
  type        = string
  description = "SKU tier for the App Service Plan. Keep as imported value to avoid unnecessary recreation."
  default     = "Premium0V3"
}

variable "app_service_plan_sku_family" {
  type        = string
  description = "SKU family for the App Service Plan."
  default     = "Pv3"
}

variable "app_service_plan_sku_size" {
  type        = string
  description = "SKU size for the App Service Plan. Usually matches sku name."
  default     = "P0v3"
}

variable "app_service_plan_capacity" {
  type        = number
  description = "Instance capacity for the App Service Plan."
  default     = 1
}

#############################
# Frontend App Service Variables
#############################
variable "frontend_app_service_name" {
  type        = string
  description = "Explicit name for the frontend App Service (leave blank to auto-generate)."
  default     = ""
}

variable "frontend_linux_fx_version" {
  type        = string
  description = "Linux FX runtime string (e.g. NODE|20-lts)."
  default     = "NODE|20-lts"
}

variable "frontend_https_only" {
  type        = bool
  description = "Force HTTPS only."
  default     = true
}

variable "frontend_minimum_elastic_instance_count" {
  type        = number
  description = "Minimum elastic instance count (scale floor)."
  default     = 1
}

variable "frontend_number_of_workers" {
  type        = number
  description = "Number of workers (overrides plan capacity for some SKUs; usually keep 1)."
  default     = 1
}

#############################
# Drupal App Service Variables
#############################
variable "drupal_app_service_name" {
  type        = string
  description = "Explicit name for the Drupal App Service (leave blank to auto-generate)."
  default     = ""
}

variable "drupal_linux_fx_version" {
  type        = string
  description = "Linux FX runtime string for Drupal/PHP (e.g. PHP|8.2)."
  default     = "PHP|8.2"
}

variable "drupal_https_only" {
  type        = bool
  description = "Force HTTPS only for Drupal site."
  default     = true
}

variable "drupal_minimum_elastic_instance_count" {
  type        = number
  description = "Minimum elastic instance count for Drupal site."
  default     = 1
}

variable "drupal_number_of_workers" {
  type        = number
  description = "Number of workers for Drupal site."
  default     = 1
}

#############################
# Redis Enterprise Cache Variables
#############################
variable "redis_enterprise_name" {
  type        = string
  description = "Explicit name for Redis Enterprise cache (leave blank to auto-generate)."
  default     = ""
}

variable "redis_sku_name" {
  type        = string
  description = "SKU name for Redis Enterprise (e.g. Balanced_B0, Enterprise_E10)."
  default     = "Balanced_B0"
}

variable "redis_high_availability" {
  type        = string
  description = "High availability setting (Enabled or Disabled)."
  default     = "Disabled"
}

variable "redis_minimum_tls_version" {
  type        = string
  description = "Minimum TLS version (e.g. 1.2)."
  default     = "1.2"
}

variable "redis_private_endpoint_group_ids" {
  type        = list(string)
  description = "Group IDs used for the Redis Enterprise private endpoint connection (verify valid values; commonly 'redisEnterprise' or 'redisCache')."
  default     = ["redisEnterprise"]
}

#############################
# MySQL Flexible Server Variables
#############################
variable "mysql_flexible_server_name" {
  type        = string
  description = "Explicit name for MySQL flexible server (leave blank to auto-generate)."
  default     = ""
}

variable "mysql_version" {
  type        = string
  description = "MySQL server version."
  default     = "8.0.21"
}

variable "mysql_administrator_login" {
  type        = string
  description = "Administrator login username (no password variable included; assume already existing or managed externally)."
  default     = "sqlprodadmin"
}

variable "mysql_administrator_password" {
  type        = string
  description = "Administrator password for MySQL flexible server (supply via tfvars or environment, keep secret). Must meet Azure MySQL password complexity requirements."
  sensitive   = true
  default     = "My$QL@password123"
}

variable "mysql_availability_zone" {
  type        = string
  description = "Availability zone for the server (e.g. '1','2','3')."
  default     = "2"
}

variable "mysql_high_availability_mode" {
  type        = string
  description = "High availability mode (Disabled, ZoneRedundant, SameZone)."
  default     = "Disabled"
}

variable "mysql_backup_retention_days" {
  type        = number
  description = "Backup retention in days."
  default     = 7
}

variable "mysql_backup_geo_redundant" {
  type        = string
  description = "Geo redundant backup setting (Enabled or Disabled)."
  default     = "Enabled" # switched to Enabled to make MySQL geo redundant
}

variable "mysql_storage_size_gb" {
  type        = number
  description = "Allocated storage size in GB."
  default     = 76
}

variable "mysql_storage_iops" {
  type        = number
  description = "Provisioned IOPS."
  default     = 528
}

variable "mysql_storage_redundancy" {
  type        = string
  description = "Storage redundancy setting (ZoneRedundancy, GeoRedundancy, etc)."
  default     = "ZoneRedundancy" # GeoRedundancy not supported for current SKU/region; revert to zone redundancy
}

variable "mysql_storage_auto_grow" {
  type        = string
  description = "Auto grow setting (Enabled/Disabled)."
  default     = "Enabled"
}

variable "mysql_storage_auto_io_scaling" {
  type        = string
  description = "Auto IO scaling setting (Enabled/Disabled)."
  default     = "Enabled"
}

variable "mysql_sku_name" {
  type        = string
  description = "SKU name (e.g. Standard_B2s)."
  default     = "Standard_D4ads_v5"
}

variable "mysql_sku_tier" {
  type        = string
  description = "SKU tier (e.g. Burstable, GeneralPurpose, MemoryOptimized)."
  default     = "GeneralPurpose"
}

variable "mysql_public_network_access" {
  type        = string
  description = "Public network access (Enabled/Disabled). Consider Disabled with private endpoint."
  default     = "Enabled"
}

variable "mysql_private_endpoint_group_ids" {
  type        = list(string)
  description = "Group IDs for MySQL private endpoint (typically ['mysqlServer'])."
  default     = ["mysqlServer"]
}

#############################
# Front Door (Standard/Premium) Variables
#############################
variable "frontdoor_profile_name" {
  type        = string
  description = "Explicit Front Door profile name (leave blank to auto-generate)."
  default     = ""
}

variable "frontdoor_sku_name" {
  type        = string
  description = "Front Door SKU name (Standard_AzureFrontDoor or Premium_AzureFrontDoor)."
  default     = "Standard_AzureFrontDoor"
}

variable "frontdoor_origin_response_timeout_seconds" {
  type        = number
  description = "Origin response timeout in seconds."
  default     = 60
}

variable "frontdoor_endpoint_name" {
  type        = string
  description = "Name for the Front Door endpoint (leave blank to auto-generate)."
  default     = ""
}

