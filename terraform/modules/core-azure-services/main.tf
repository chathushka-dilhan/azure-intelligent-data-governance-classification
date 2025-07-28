# Terraform module for core Azure services
# This module sets up essential Azure resources for the project, including:
# - Azure Data Lake Storage Gen2 (ADLS Gen2) for data storage
# - Azure Cosmos DB for metadata and governance
# - Azure Function App Service Plan for serverless functions

# Use the existing resource group created by the network-security module
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# --- Azure Data Lake Storage Gen2 (ADLS Gen2) ---
# The primary data lake for raw and processed data.
resource "random_string" "adls_suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "adls_gen2" {
  name                     = var.adls_gen2_account_name
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Or "GRS" for geo-redundancy
  access_tier              = "StorageV2"
  is_hns_enabled           = true # Enable Hierarchical Namespace for Data Lake Gen2
  min_tls_version          = "TLS1_2"

  # Restrict public access and allow only from specific VNet/subnets
  network_rules {
    default_action             = "Deny"
    ip_rules                   = []                              # No public IP access
    virtual_network_subnet_ids = [var.subnet_ids.data_subnet_id] # Allow access from data subnet
    bypass                     = ["AzureServices"]               # Allow trusted Azure services
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Private Endpoint for ADLS Gen2 for secure access from within VNet
resource "azurerm_private_endpoint" "adls_pe" {
  name                = "${var.project_name}-adls-pe-${random_string.adls_suffix.result}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  subnet_id           = var.subnet_ids.data_subnet_id # Deploy PE in the data subnet

  private_service_connection {
    name                           = "${var.project_name}-adls-pls-conn"
    private_connection_resource_id = azurerm_storage_account.adls_gen2.id
    is_manual_connection           = false
    subresource_names              = ["blob"] # Connect to the blob service endpoint
  }

  private_dns_zone_group {
    name                 = "${var.project_name}-adls-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.adls_dns_zone.id]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Private DNS Zone for ADLS Gen2
resource "azurerm_private_dns_zone" "adls_dns_zone" {
  name                = "privatelink.blob.core.windows.net"   # Standard private DNS zone for blob storage
  resource_group_name = data.azurerm_resource_group.main.name # Deploy in the same RG
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_virtual_network_link" "adls_vnet_link" {
  name                  = "${var.project_name}-adls-vnet-link-${random_string.adls_suffix.result}"
  resource_group_name   = data.azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.adls_dns_zone.name
  virtual_network_id    = data.azurerm_subnet.data_subnet.virtual_network_id # Use VNet ID from data subnet
  registration_enabled  = false                                              # Don't register VMs from this VNet in this zone

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Data source for the VNet of the data subnet (to get VNet ID for DNS link)
data "azurerm_subnet" "data_subnet" {
  name                 = var.subnet_ids.data_subnet_name
  id                   = var.subnet_ids.data_subnet_id
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
}

# Create a Filesystem (Container) within the ADLS Gen2 account
resource "azurerm_storage_container" "adls_gen2_filesystem" {
  name                  = "${var.project_name}-data" # Main filesystem for data
  storage_account_id    = azurerm_storage_account.adls_gen2.id
  container_access_type = "private" # Ensure no public access

  # No direct tags for containers in AzureRM provider, tags are on storage account
}

# --- Azure Cosmos DB (NoSQL API) ---
# Stores classification metadata, data quality scores, and other governance-related data.
resource "random_string" "cosmos_suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_cosmosdb_account" "main" {
  name                          = "${var.cosmos_db_account_name}${random_string.cosmos_suffix.result}"
  location                      = data.azurerm_resource_group.main.location
  resource_group_name           = data.azurerm_resource_group.main.name
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB" # For NoSQL API
  public_network_access_enabled = false              # Disable public access

  consistency_policy {
    consistency_level = "Session" # Or Strong, BoundedStaleness, Eventual
  }

  # Use serverless for cost optimization
  capabilities {
    name = "EnableServerless"
  }

  # Configure VNet integration for Cosmos DB
  # Needs to ensure the subnet is configured with 'Microsoft.DocumentDB' service endpoint delegation
  virtual_network_rule {
    id = var.subnet_ids.data_subnet_id # Allow access from data subnet
  }

  geo_location {
    location          = data.azurerm_resource_group.main.location
    failover_priority = 0
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Cosmos DB SQL Database
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = var.cosmos_db_database_name
  resource_group_name = data.azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  throughput          = 400 # Or autoscale settings
}

# Cosmos DB SQL Container
resource "azurerm_cosmosdb_sql_container" "main" {
  name                  = var.cosmos_db_container_name
  resource_group_name   = data.azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.main.name
  database_name         = azurerm_cosmosdb_sql_database.main.name
  partition_key_version = 1   # Use version 1 for hash partitioning
  throughput            = 400 # Or autoscale settings
  partition_key_paths = [
    "/filePath", # Partition by file path
  ]
}

# --- Azure Function App Service Plan (Re-used by Functions) ---
# A single App Service Plan can host multiple Function Apps.
resource "azurerm_app_service_plan" "function_app_plan" {
  name                = "${var.function_app_service_plan_name}-${random_string.adls_suffix.result}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic" # Consumption plan
    size = "Y1"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# --- Azure Function App Storage Account (Re-used by Functions) ---
# Each Function App requires a storage account. We create one here and reuse it.
resource "random_string" "func_storage_suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "function_app_storage" {
  name                     = "${var.function_app_storage_account_name}${random_string.func_storage_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "StorageV2"
  min_tls_version          = "TLS1_2"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}