# __generated__ by Terraform

## Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "/subscriptions/c785c74c-7bd9-4afa-ac0a-c5d7912e2fda/resourceGroups/site-group-tmpprod/providers/Microsoft.Web/serverFarms/site-appserviceplan-tmpprod"
resource "azapi_resource" "app_service_plan" {
  name      = local.app_service_plan_name_effective
  type      = "Microsoft.Web/serverFarms@2024-04-01"
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${local.resource_group_name}"
  location  = var.location
  tags      = local.merged_tags

  body = {
    kind = "linux"
    properties = {
      elasticScaleEnabled       = true
      freeOfferExpirationTime   = null
      hostingEnvironmentProfile = null
      hyperV                    = false
      isSpot                    = false
      isXenon                   = false
      kubeEnvironmentProfile    = null
      maximumElasticWorkerCount = 3
      perSiteScaling            = false
      reserved                  = true
      spotExpirationTime        = null
      targetWorkerCount         = 0
      targetWorkerSizeId        = 0
      workerTierName            = null
      zoneRedundant             = false
    }
    sku = {
      capacity = var.app_service_plan_capacity
      family   = var.app_service_plan_sku_family
      name     = var.app_service_plan_sku_name
      size     = var.app_service_plan_sku_size
      tier     = var.app_service_plan_sku_tier
    }
  }
  ignore_missing_property   = true
  schema_validation_enabled = true
}
