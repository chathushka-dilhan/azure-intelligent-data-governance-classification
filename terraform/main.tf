# This is the root Terraform configuration file.
# It orchestrates the deployment of all modular components of the Azure Data Lake Sentinel.

locals {
  adls_gen2_account_name = "${var.project_name}adlsgen2${random_string.adls_suffix.result}"
}

# --- Modules ---

# 1. Network Security Module
# Provisions Virtual Networks, Subnets, Network Security Groups, and Route Tables.
# This is foundational and creates the central resource group.
module "network_security" {
  source = "./modules/network-security"

  project_name  = var.project_name
  location      = var.location
  environment   = var.environment
  owner         = var.owner
  vnet_cidr     = var.vnet_cidr
  subnet_cidrs  = var.subnet_cidrs
}

# 2. Core Azure Services Module
# Provisions core services like ADLS Gen2 and Cosmos DB.
# It reuses the resource group created by the network-security module.
module "core_azure_services" {
  source = "./modules/core-azure-services"

  project_name      = var.project_name
  location          = var.location
  environment       = var.environment
  owner             = var.owner
  resource_group_name = module.network_security.resource_group_name # Dependency on network module
  virtual_network_name = "${var.project_name}-vnet-${var.environment}"
  subnet_ids        = {
    data_subnet_id = module.network_security.subnet_ids["data-subnet"]
    # Add other subnet IDs as needed for private endpoints or VNet integration
  }
  cosmos_db_account_name = var.cosmos_db_account_name
  cosmos_db_database_name = var.cosmos_db_database_name
  cosmos_db_container_name = var.cosmos_db_container_name
  # Function App Service Plan and Storage Account are now created here for reuse
  function_app_service_plan_name = var.function_app_service_plan_name
  function_app_storage_account_name = var.function_app_storage_account_name
  adls_gen2_account_name = local.adls_gen2_account_name # Use local variable for ADLS Gen2 name
}

# 3. Data Ingestion & Eventing Module
# Sets up Event Hubs, Event Grid subscriptions, and Azure Functions for ingestion.
module "data_ingestion_eventing" {
  source = "./modules/data-ingestion-eventing"

  project_name            = var.project_name
  location                = var.location
  environment             = var.environment
  owner                   = var.owner
  resource_group_name     = module.network_security.resource_group_name
  adls_gen2_account_name  = module.core_azure_services.adls_gen2_account_name # Dependency on core services
  function_app_service_plan_id = module.core_azure_services.function_app_service_plan_id # Re-use ASP
  function_app_storage_account_name = module.core_azure_services.function_app_storage_account_name # Re-use Storage Account
  function_subnet_id      = module.network_security.subnet_ids["function-subnet"] # Function VNet integration
  event_hub_namespace_name = var.event_hub_namespace_name
  event_hub_name          = var.event_hub_name
}

# 4. Data Analytics & ML Module
# Provisions Azure Synapse Analytics, Azure ML Workspace, and AKS/ACI for AML endpoints.
module "data_analytics_ml" {
  source = "./modules/data-analytics-ml"

  project_name            = var.project_name
  location                = var.location
  environment             = var.environment
  owner                   = var.owner
  resource_group_name     = module.network_security.resource_group_name
  adls_gen2_filesystem_id = module.core_azure_services.adls_gen2_filesystem_id # Dependency on core services
  synapse_managed_vnet_subnet_id = module.network_security.subnet_ids["synapse-managed-vnet-subnet"] # Synapse Managed VNet
  synapse_managed_vnet_subnet_name = var.synapse_managed_vnet_subnet_name
  ml_subnet_id            = module.network_security.subnet_ids["ml-subnet"] # For AML compute
  synapse_workspace_name  = var.synapse_workspace_name
  azure_ml_workspace_name = var.azure_ml_workspace_name
  adls_gen2_filesystem_name = local.adls_gen2_account_name # Use local variable for filesystem name
  virtual_network_name = "${var.project_name}-vnet-${var.environment}"
}

# 5. AI & Cognitive Services Module
# Provisions Azure OpenAI Service and/or other Azure Cognitive Services.
module "ai_cognitive_services" {
  source = "./modules/ai-cognitive-services"

  project_name                 = var.project_name
  location                     = var.location
  environment                  = var.environment
  owner                        = var.owner
  resource_group_name          = module.network_security.resource_group_name
  open_ai_account_name         = var.open_ai_account_name
  cognitive_services_account_name = var.cognitive_services_account_name
}

# 6. Metadata Governance Module
# Provisions Azure Functions for metadata updates and Logic Apps for alerts.
module "metadata_governance" {
  source = "./modules/metadata-governance"

  project_name            = var.project_name
  location                = var.location
  environment             = var.environment
  owner                   = var.owner
  resource_group_name     = module.network_security.resource_group_name
  cosmos_db_endpoint      = module.core_azure_services.cosmos_db_endpoint # Dependency on core services
  cosmos_db_primary_key   = module.core_azure_services.cosmos_db_primary_key
  cosmos_db_database_name = module.core_azure_services.cosmos_db_database_name
  cosmos_db_container_name = module.core_azure_services.cosmos_db_container_name
  function_app_service_plan_id = module.core_azure_services.function_app_service_plan_id # Re-use ASP
  function_app_service_plan_name = module.core_azure_services.function_app_service_plan_name # Re-use ASP name
  function_app_storage_account_name = module.core_azure_services.function_app_storage_account_name # Re-use Storage Account
  function_subnet_id      = module.network_security.subnet_ids["function-subnet"] # Function VNet integration
  logic_app_name          = var.logic_app_name
  notification_email      = var.notification_email
}