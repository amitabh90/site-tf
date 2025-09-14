# Remote state backend configuration for prod environment (Azure Blob Storage)
# Ensure the storage resources already exist (same as root). Use a unique key per environment.
terraform {
  backend "azurerm" {
    resource_group_name  = "site-tfstate-prod"
    storage_account_name = "tnmtfstateprod" # change to actual
    container_name       = "tfstate"
    key                  = "prod/infra.tfstate"
    use_azuread_auth     = false
  }
}
