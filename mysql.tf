# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "/subscriptions/c785c74c-7bd9-4afa-ac0a-c5d7912e2fda/resourceGroups/site-group-tmpprod/providers/Microsoft.DBforMySQL/flexibleServers/site-myslqserver-tmpprod"
resource "azapi_resource" "mysql_flexible_server" {
  name      = local.mysql_flexible_server_name_effective
  type      = "Microsoft.DBforMySQL/flexibleServers@2024-10-01-preview"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${local.resource_group_name}"
  tags      = local.merged_tags

  body = {
    properties = {
      administratorLogin         = var.mysql_administrator_login
      availabilityZone           = var.mysql_availability_zone
      administratorLoginPassword = var.mysql_administrator_password
      backup = {
        backupIntervalHours = 24
        backupRetentionDays = var.mysql_backup_retention_days
        geoRedundantBackup  = var.mysql_backup_geo_redundant
      }
      highAvailability = {
        mode                    = var.mysql_high_availability_mode
        standbyAvailabilityZone = "" // Could parameterize later
      }
      maintenancePolicy = {
        patchStrategy = "Regular"
      }
      maintenanceWindow = {
        customWindow = "Disabled"
        dayOfWeek    = 0
        startHour    = 0
        startMinute  = 0
      }
      network = {
        publicNetworkAccess = var.mysql_public_network_access
      }
      replicationRole = "None"
      storage = {
        autoGrow      = var.mysql_storage_auto_grow
        autoIoScaling = var.mysql_storage_auto_io_scaling
        iops          = var.mysql_storage_iops
        logOnDisk     = "Disabled"
        storageSizeGB = var.mysql_storage_size_gb
      }
      version = var.mysql_version
    }
    sku = {
      name = var.mysql_sku_name
      tier = var.mysql_sku_tier
    }
  }

  ignore_missing_property   = true
  schema_validation_enabled = true
}

# Private Endpoint for MySQL flexible server in database subnet
resource "azapi_resource" "mysql_private_endpoint" {
  name      = "${local.mysql_flexible_server_name_effective}-pep"
  type      = "Microsoft.Network/privateEndpoints@2023-09-01"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${local.resource_group_name}"
  tags      = merge(local.merged_tags, { component = "mysql-private-endpoint" })

  body = {
    properties = {
      subnet = {
        id = "${azapi_resource.site-vnet.id}/subnets/${var.subnets["database"].name}"
      }
      privateLinkServiceConnections = [
        {
          name = "${local.mysql_flexible_server_name_effective}-plink"
          properties = {
            privateLinkServiceId = azapi_resource.mysql_flexible_server.id
            groupIds             = var.mysql_private_endpoint_group_ids
            requestMessage       = "Access to MySQL Flexible Server"
          }
        }
      ]
    }
  }

  ignore_missing_property   = true
  schema_validation_enabled = true

  depends_on = [azapi_resource.mysql_flexible_server, azapi_resource.site-vnet]
}
