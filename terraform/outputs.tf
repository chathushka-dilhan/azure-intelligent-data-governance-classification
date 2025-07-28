# --- Network Security Outputs ---
output "resource_group_name" {
  description = "Name of the main resource group created by the network security module."
  value       = module.network_security.resource_group_name
}

output "vnet_name" {
  description = "Name of the main Virtual Network."
  value       = module.network_security.vnet_name
}

output "subnet_ids" {
  description = "Map of subnet names to their resource IDs."
  value       = module.network_security.subnet_ids
}

# --- Core Azure Services Outputs ---
output "adls_gen2_account_name" {
  description = "Name of the Azure Data Lake Storage Gen2 account."
  value       = module.core_azure_services.adls_gen2_account_name
}

output "adls_gen2_filesystem_name" {
  description = "Name of the primary filesystem (container) in ADLS Gen2."
  value       = module.core_azure_services.adls_gen2_filesystem_name
}

output "cosmos_db_endpoint" {
  description = "Endpoint URL for the Azure Cosmos DB account."
  value       = module.core_azure_services.cosmos_db_endpoint
}

output "cosmos_db_primary_key" {
  description = "Primary key for the Azure Cosmos DB account (sensitive)."
  value       = module.core_azure_services.cosmos_db_primary_key
  sensitive   = true
}

output "function_app_service_plan_id" {
  description = "ID of the Azure Function App Service Plan."
  value       = module.core_azure_services.function_app_service_plan_id
}

output "function_app_storage_account_name" {
  description = "Name of the Azure Function App's storage account."
  value       = module.core_azure_services.function_app_storage_account_name
}

# --- Data Ingestion & Eventing Outputs ---
output "event_hub_namespace_name" {
  description = "Name of the Azure Event Hubs Namespace."
  value       = module.data_ingestion_eventing.event_hub_namespace_name
}

output "event_hub_name" {
  description = "Name of the Azure Event Hub."
  value       = module.data_ingestion_eventing.event_hub_name
}

# --- Data Analytics & ML Outputs ---
output "synapse_workspace_name" {
  description = "Name of the Azure Synapse Analytics Workspace."
  value       = module.data_analytics_ml.synapse_workspace_name
}

output "azure_ml_workspace_name" {
  description = "Name of the Azure Machine Learning Workspace."
  value       = module.data_analytics_ml.azure_ml_workspace_name
}

# --- AI & Cognitive Services Outputs ---
output "open_ai_account_name" {
  description = "Name of the Azure OpenAI Service account."
  value       = module.ai_cognitive_services.open_ai_account_name
}

output "cognitive_services_account_name" {
  description = "Name of the Azure Cognitive Services account."
  value       = module.ai_cognitive_services.cognitive_services_account_name
}

# --- Metadata Governance Outputs ---
output "logic_app_http_trigger_url" {
  description = "HTTP POST endpoint URL for the Logic App (sensitive)."
  value       = module.metadata_governance.logic_app_http_trigger_url
  sensitive   = true
}