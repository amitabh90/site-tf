# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "/subscriptions/c785c74c-7bd9-4afa-ac0a-c5d7912e2fda/resourceGroups/site-group-tmpprod/providers/Microsoft.Cdn/profiles/site-frontdoor-tmpprod"
resource "azapi_resource" "frontdoor_profile" {
  name      = local.frontdoor_profile_name_effective
  type      = "Microsoft.Cdn/profiles@2025-04-15"
  location  = "global"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${local.resource_group_name}"
  tags      = local.merged_tags

  body = {
    properties = {
      originResponseTimeoutSeconds = var.frontdoor_origin_response_timeout_seconds
    }
    sku = {
      name = var.frontdoor_sku_name
    }
  }

  ignore_missing_property   = true
  schema_validation_enabled = true
}

# Front Door Endpoint (basic)
resource "azapi_resource" "frontdoor_endpoint" {
  name      = local.frontdoor_endpoint_name_effective
  type      = "Microsoft.Cdn/profiles/afdEndpoints@2024-09-01"
  parent_id = azapi_resource.frontdoor_profile.id
  location  = "global"
  tags      = local.merged_tags

  body = {
    properties = {
      enabledState = "Enabled"
    }
  }

  ignore_missing_property   = true
  schema_validation_enabled = true
}

# Optional Private Endpoint for Front Door endpoint into front subnet
