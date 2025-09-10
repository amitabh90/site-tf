// Azure Virtual Network with 3 subnets using AZAPI provider
// NOTE: This file has been parameterized. See variables in variables.tf and provide values via *.tfvars (e.g. prod.tfvars).

# Virtual Network
resource "azapi_resource" "site-vnet" { // renamed from site-vnet-tmpprod
  type      = "Microsoft.Network/virtualNetworks@2023-09-01"
  name      = local.vnet_name
  parent_id = azapi_resource.site-group.id
  location  = azapi_resource.site-group.location

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = var.vnet_address_space
      }
      subnets = [
        {
          name = var.subnets["front"].name
          properties = {
            addressPrefix        = var.subnets["front"].address_prefix
            networkSecurityGroup = { id = azapi_resource.site-nsg-front.id }
          }
        },
        {
          name = var.subnets["app"].name
          properties = {
            addressPrefix        = var.subnets["app"].address_prefix
            networkSecurityGroup = { id = azapi_resource.site-nsg-app.id }
            serviceEndpoints     = [for s in var.subnets["app"].service_endpoints : { service = s }]
            delegations = [
              {
                name = "webapp_delegation"
                properties = {
                  serviceName = "Microsoft.Web/serverFarms"
                }
              }
            ]
          }
        },
        {
          name = var.subnets["database"].name
          properties = {
            addressPrefix        = var.subnets["database"].address_prefix
            networkSecurityGroup = { id = azapi_resource.site-nsg-database.id }
            serviceEndpoints     = [for s in var.subnets["database"].service_endpoints : { service = s }]
          }
        }
      ]
    }
  }

  tags                      = local.merged_tags
  schema_validation_enabled = false # disable due to delegation schema mismatch in provider
}

# Network Security Group for front subnet
resource "azapi_resource" "site-nsg-front" {
  type      = "Microsoft.Network/networkSecurityGroups@2023-09-01"
  name      = local.nsg_names["front"]
  parent_id = azapi_resource.site-group.id
  location  = azapi_resource.site-group.location

  body = {
    properties = {
      securityRules = [
        {
          name = "AllowVnetInBound"
          properties = {
            priority                 = 100
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "VirtualNetwork"
            destinationAddressPrefix = "VirtualNetwork"
          }
        },
        {
          name = "AllowFrontDoorInBound"
          properties = {
            priority                 = 200
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRanges    = ["80", "443"]
            sourceAddressPrefix      = "AzureFrontDoor.Backend"
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "AllowAzureLoadBalancerInBound"
          properties = {
            priority                 = 110
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "AzureLoadBalancer"
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "AllowAzureServicesInBound"
          properties = {
            priority             = 300
            direction            = "Inbound"
            access               = "Allow"
            protocol             = "*"
            sourcePortRange      = "*"
            destinationPortRange = "*"
            // Reuse the app subnet CIDR variable/local instead of hard-coded value
            sourceAddressPrefix      = local.app_subnet_cidr_effective
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "DenyAllInBound"
          properties = {
            priority                 = 4096
            direction                = "Inbound"
            access                   = "Deny"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "*"
            destinationAddressPrefix = "*"
          }
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "network-security-group", subnet = "front" })
}

# Network Security Group for app subnet
resource "azapi_resource" "site-nsg-app" {
  type      = "Microsoft.Network/networkSecurityGroups@2023-09-01"
  name      = local.nsg_names["app"]
  parent_id = azapi_resource.site-group.id
  location  = azapi_resource.site-group.location

  body = {
    properties = {
      securityRules = [
        {
          name = "AllowVnetInBound"
          properties = {
            priority                 = 100
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "VirtualNetwork"
            destinationAddressPrefix = "VirtualNetwork"
          }
        },
        {
          name = "AllowFrontDoorInBound"
          properties = {
            priority                 = 200
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRanges    = ["80", "443"]
            sourceAddressPrefix      = "AzureFrontDoor.Backend"
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "AllowAppServiceInBound"
          properties = {
            priority                 = 300
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRanges    = ["80", "443"]
            sourceAddressPrefix      = "Internet"
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "AllowAzureLoadBalancerInBound"
          properties = {
            priority                 = 110
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "AzureLoadBalancer"
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "AllowAppServiceManagementInBound"
          properties = {
            priority                 = 400
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRanges    = ["80", "443", "8172"]
            sourceAddressPrefix      = "AppServiceManagement"
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "DenyAllInBound"
          properties = {
            priority                 = 4096
            direction                = "Inbound"
            access                   = "Deny"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "*"
            destinationAddressPrefix = "*"
          }
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "network-security-group", subnet = "app" })
}

# Network Security Group for database subnet
resource "azapi_resource" "site-nsg-database" {
  type      = "Microsoft.Network/networkSecurityGroups@2023-09-01"
  name      = local.nsg_names["database"]
  parent_id = azapi_resource.site-group.id
  location  = azapi_resource.site-group.location

  body = {
    properties = {
      securityRules = [
        {
          name = "AllowVnetInBound"
          properties = {
            priority                 = 100
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "VirtualNetwork"
            destinationAddressPrefix = "VirtualNetwork"
          }
        },
        {
          name = "AllowAppSubnetMySQLInBound"
          properties = {
            priority                 = 200
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "Tcp"
            sourcePortRange          = "*"
            destinationPortRange     = "3306"
            sourceAddressPrefix      = local.app_subnet_cidr_effective
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "AllowAppSubnetRedisInBound"
          properties = {
            priority                 = 210
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "Tcp"
            sourcePortRange          = "*"
            destinationPortRange     = "10000-19999"
            sourceAddressPrefix      = local.app_subnet_cidr_effective
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "AllowAzureServicesInBound"
          properties = {
            priority                 = 300
            direction                = "Inbound"
            access                   = "Allow"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = local.app_subnet_cidr_effective
            destinationAddressPrefix = "*"
          }
        },
        {
          name = "DenyAllInBound"
          properties = {
            priority                 = 4096
            direction                = "Inbound"
            access                   = "Deny"
            protocol                 = "*"
            sourcePortRange          = "*"
            destinationPortRange     = "*"
            sourceAddressPrefix      = "*"
            destinationAddressPrefix = "*"
          }
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "network-security-group", subnet = "database" })
}

# Outputs
output "virtual_network_id" {
  description = "The ID of the Virtual Network"
  value       = azapi_resource.site-vnet.id
}

output "virtual_network_name" {
  description = "The name of the Virtual Network"
  value       = azapi_resource.site-vnet.name
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value = {
    for k, subnet in var.subnets : k => "${azapi_resource.site-vnet.id}/subnets/${subnet.name}"
  }
}

output "network_security_group_ids" {
  description = "The IDs of the Network Security Groups"
  value = {
    front    = azapi_resource.site-nsg-front.id
    app      = azapi_resource.site-nsg-app.id
    database = azapi_resource.site-nsg-database.id
  }
}
