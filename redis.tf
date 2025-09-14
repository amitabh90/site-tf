# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "/subscriptions/c785c74c-7bd9-4afa-ac0a-c5d7912e2fda/resourceGroups/site-group-tmpprod/providers/Microsoft.Cache/redisEnterprise/site-rediscache-tmpprod"
resource "azapi_resource" "redis_enterprise" {
  name      = local.redis_enterprise_name_effective
  type      = "Microsoft.Cache/redisEnterprise@2025-05-01-preview"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${local.resource_group_name}"
  tags      = local.merged_tags

  body = {
    properties = {
      highAvailability  = var.redis_high_availability
      minimumTlsVersion = var.redis_minimum_tls_version
    }
    sku = {
      name = var.redis_sku_name
    }
  }

  ignore_missing_property   = true
  schema_validation_enabled = true
}

# Private Endpoint for Redis Enterprise (exposes to database subnet)
resource "azapi_resource" "redis_private_endpoint" {
  name      = "${local.redis_enterprise_name_effective}-pep"
  type      = "Microsoft.Network/privateEndpoints@2023-09-01"
  location  = var.location
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${local.resource_group_name}"
  tags      = merge(local.merged_tags, { component = "redis-private-endpoint" })

  body = {
    properties = {
      subnet = {
        id = "${azapi_resource.site-vnet.id}/subnets/${var.subnets["database"].name}"
      }
      privateLinkServiceConnections = [
        {
          name = "${local.redis_enterprise_name_effective}-plink"
          properties = {
            privateLinkServiceId = azapi_resource.redis_enterprise.id
            groupIds             = var.redis_private_endpoint_group_ids
            requestMessage       = "Access to Redis Enterprise"
          }
        }
      ]
    }
  }

  ignore_missing_property   = true
  schema_validation_enabled = true

  depends_on = [azapi_resource.redis_enterprise, azapi_resource.site-vnet]
}
