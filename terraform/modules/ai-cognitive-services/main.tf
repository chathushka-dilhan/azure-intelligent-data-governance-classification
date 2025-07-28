# Terraform module for Azure Cognitive Services
# This module sets up Azure Cognitive Services accounts for OpenAI and other cognitive services.

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# --- Azure OpenAI Service Account ---
# Provides access to powerful large language models for classification explanations and more.
resource "random_string" "openai_suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_cognitive_account" "openai" {
  name                = "${var.open_ai_account_name}${random_string.openai_suffix.result}" # Must be globally unique
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  kind                = "OpenAI" # Specific kind for OpenAI
  sku_name            = "S0"     # Standard tier for OpenAI

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# --- Azure Cognitive Services Account (for other services like Text Analytics, Computer Vision) ---
# Can be used for built-in PII detection, OCR, form recognition etc.
resource "random_string" "cognitive_suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_cognitive_account" "cognitive_services" {
  name                = "${var.cognitive_services_account_name}${random_string.cognitive_suffix.result}" # Must be globally unique
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  kind                = "TextAnalytics,ComputerVision,FormRecognizer" # Example kinds, choose based on needs
  sku_name            = "S0"                                          # Standard tier

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}