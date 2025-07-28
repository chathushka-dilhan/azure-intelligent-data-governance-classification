output "event_hub_namespace_name" {
  description = "Name of the Azure Event Hubs Namespace."
  value       = azurerm_eventhub_namespace.main.name
}

output "event_hub_name" {
  description = "Name of the Azure Event Hub."
  value       = azurerm_eventhub.main.name
}

output "event_grid_trigger_function_id" {
  description = "ID of the Event Grid Trigger Azure Function."
  value       = azurerm_function_app.event_grid_trigger_function.id
}

output "event_grid_trigger_function_identity_principal_id" {
  description = "Principal ID of the Event Grid Trigger Azure Function's Managed Identity."
  value       = azurerm_function_app.event_grid_trigger_function.identity[0].principal_id
}
