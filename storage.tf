// Storage Account 
resource "azapi_resource" "site-storage" {
  type      = "Microsoft.Storage/storageAccounts@2024-01-01"
  name      = local.storage_account_name
  parent_id = azapi_resource.site-group.id
  location  = var.location

  body = {
    kind = var.storage_account_kind
    sku  = { name = var.storage_account_sku }
    properties = {
      accessTier                   = var.storage_access_tier
      allowBlobPublicAccess        = var.storage_allow_blob_public_access
      allowCrossTenantReplication  = false
      allowSharedKeyAccess         = var.storage_allow_shared_key_access
      defaultToOAuthAuthentication = false
      dnsEndpointType              = "Standard"
      encryption = {
        keySource                       = "Microsoft.Storage"
        requireInfrastructureEncryption = false
        services = {
          blob = { enabled = true, keyType = "Account" }
          file = { enabled = true, keyType = "Account" }
        }
      }
      largeFileSharesState = var.storage_large_file_shares_enabled ? "Enabled" : null
      minimumTlsVersion    = var.storage_min_tls_version
      networkAcls = {
        bypass              = "AzureServices"
        defaultAction       = "Allow"
        ipRules             = []
        virtualNetworkRules = []
      }
      publicNetworkAccess      = var.storage_public_network_access
      supportsHttpsTrafficOnly = var.storage_supports_https_traffic_only
    }
  }

  tags = merge(local.merged_tags, { purpose = "storage-account" })
}

output "storage_account_name" {
  value       = azapi_resource.site-storage.name
  description = "Storage account name"
}

output "storage_account_id" {
  value       = azapi_resource.site-storage.id
  description = "Storage account ID"
}
