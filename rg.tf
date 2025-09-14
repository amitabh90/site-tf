// Azure Resource Group (parameterized)
resource "azapi_resource" "site-group" { // renamed from site-group-tmpprod
  type      = "Microsoft.Resources/resourceGroups@2025-04-01"
  name      = local.resource_group_name
  parent_id = "/subscriptions/${var.subscription_id}"
  location  = var.location

  body = { properties = {} }

  // Use shared tag set
  tags = local.merged_tags
}

// Monitoring / Observability Resource Group
resource "azapi_resource" "site-groupmon" {
  type      = "Microsoft.Resources/resourceGroups@2025-04-01"
  name      = local.monitoring_resource_group_name
  parent_id = "/subscriptions/${var.subscription_id}"
  location  = var.location

  body = { properties = {} }

  tags = merge(local.merged_tags, { purpose = "monitoring" })
}

output "resource_group_id" {
  value       = azapi_resource.site-group.id
  description = "Primary resource group ID"
}

output "monitoring_resource_group_id" {
  value       = azapi_resource.site-groupmon.id
  description = "Monitoring resource group ID"
}
