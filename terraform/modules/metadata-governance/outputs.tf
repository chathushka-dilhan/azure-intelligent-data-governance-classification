output "metadata_updater_function_id" {
  description = "ID of the Metadata Updater Azure Function."
  value       = azurerm_function_app.metadata_updater_function.id
}

output "metadata_updater_function_identity_principal_id" {
  description = "Principal ID of the Metadata Updater Azure Function's Managed Identity."
  value       = azurerm_function_app.metadata_updater_function.identity[0].principal_id
}

output "logic_app_name" {
  description = "Name of the Azure Logic App."
  value       = azurerm_logic_app_workflow.notifier_logic_app.name
}

output "logic_app_http_trigger_url" {
  description = "HTTP POST endpoint URL for the Logic App (sensitive)."
  value       = azurerm_logic_app_workflow.notifier_logic_app.access_endpoint
  sensitive   = true
}
