output "open_ai_account_name" {
  description = "Name of the Azure OpenAI Service account."
  value       = azurerm_cognitive_account.openai.name
}

output "open_ai_account_endpoint" {
  description = "Endpoint URL for the Azure OpenAI Service account."
  value       = azurerm_cognitive_account.openai.endpoint
}

output "open_ai_account_primary_key" {
  description = "Primary key for the Azure OpenAI Service account (sensitive)."
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
}

output "cognitive_services_account_name" {
  description = "Name of the Azure Cognitive Services account."
  value       = azurerm_cognitive_account.cognitive_services.name
}

output "cognitive_services_account_endpoint" {
  description = "Endpoint URL for the Azure Cognitive Services account."
  value       = azurerm_cognitive_account.cognitive_services.endpoint
}

output "cognitive_services_account_primary_key" {
  description = "Primary key for the Azure Cognitive Services account (sensitive)."
  value       = azurerm_cognitive_account.cognitive_services.primary_access_key
  sensitive   = true
}