# Configure the AzureRM provider
provider "azurerm" {
  features {} # Required for AzureRM provider
  # You might authenticate via Azure CLI, Service Principal, or Managed Identity
  # client_id       = var.client_id
  # client_secret   = var.client_secret
  # tenant_id       = var.tenant_id
  # subscription_id = var.subscription_id
}

# Data source to get the current Azure subscription ID
data "azurerm_subscription" "current" {}