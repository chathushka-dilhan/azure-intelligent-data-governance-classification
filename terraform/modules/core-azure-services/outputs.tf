output "adls_gen2_account_name" {
  description = "Name of the Azure Data Lake Storage Gen2 account."
  value       = azurerm_storage_account.adls_gen2.name
}

output "adls_gen2_filesystem_name" {
  description = "Name of the primary filesystem (container) in ADLS Gen2."
  value       = azurerm_storage_container.adls_gen2_filesystem.name
}

output "adls_gen2_filesystem_id" {
  description = "ID of the primary filesystem (container) in ADLS Gen2."
  value       = azurerm_storage_container.adls_gen2_filesystem.id
}

output "cosmos_db_account_name" {
  description = "Name of the Azure Cosmos DB account."
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmos_db_endpoint" {
  description = "Endpoint URL for the Azure Cosmos DB account."
  value       = azurerm_cosmosdb_account.main.account_endpoint
}

output "cosmos_db_primary_key" {
  description = "Primary key for the Azure Cosmos DB account (sensitive)."
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

output "cosmos_db_database_name" {
  description = "Name of the Cosmos DB SQL API database."
  value       = azurerm_cosmosdb_sql_database.main.name
}

output "cosmos_db_container_name" {
  description = "Name of the Cosmos DB SQL API container."
  value       = azurerm_cosmosdb_sql_container.main.name
}

output "function_app_service_plan_id" {
  description = "ID of the Azure Function App Service Plan."
  value       = azurerm_app_service_plan.function_app_plan.id
}

output "function_app_storage_account_name" {
  description = "Name of the Azure Function App's storage account."
  value       = azurerm_storage_account.function_app_storage.name
}