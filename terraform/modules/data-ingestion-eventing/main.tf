# Terraform module for Azure Data Ingestion and Eventing
# This module sets up the necessary Azure resources for data ingestion,
# including Event Hubs, Event Grid, and Azure Functions for processing events.

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# --- Azure Event Hubs Namespace ---
# Central namespace for all Event Hubs.
resource "azurerm_eventhub_namespace" "main" {
  name                = var.event_hub_namespace_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "Standard" # Or "Basic" for development, "Premium" for high scale
  capacity            = 1          # Throughput units

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# --- Azure Event Hub ---
# The specific Event Hub to which log agents (FluentD/Bit) will send data.
resource "azurerm_eventhub" "main" {
  name              = var.event_hub_name
  namespace_id      = azurerm_eventhub_namespace.main.id
  partition_count   = 2 # Number of partitions for parallelism
  message_retention = 1 # Keep messages for 1 day
}

# --- Event Grid System Topic Subscription (for ADLS Gen2 events) ---
# Subscribes to BlobCreated/BlobUpdated events on the ADLS Gen2 account
# to trigger the 'event-grid-trigger' Azure Function.
resource "azurerm_eventgrid_system_topic_event_subscription" "adls_event_sub" {
  name                = "${var.project_name}-adls-event-sub-${var.environment}"
  resource_group_name = data.azurerm_resource_group.main.name
  system_topic        = var.adls_gen2_account_name

  # Filter for BlobCreated and BlobUpdated events
  included_event_types = ["Microsoft.Storage.BlobCreated", "Microsoft.Storage.BlobUpdated"]
  # Optional: Subject filters if you want to limit to specific paths/folders
  # subject_filter {
  #   subject_begins_with = "/blobServices/default/containers/${var.adls_gen2_container_name}/blobs/raw/"
  #   subject_ends_with   = ".json"
  # }

  delivery_identity {
    type = "SystemAssigned" # Use System-Assigned Managed Identity for Event Grid
  }

  azure_function_endpoint {
    function_id                       = azurerm_function_app.event_grid_trigger_function.id
    max_events_per_batch              = 10 # Batch events for efficiency
    preferred_batch_size_in_kilobytes = 64 # Max batch size
  }

  labels = ["data-ingestion"]
}

data "azurerm_subscription" "current" {}

# --- Azure Function App (event-grid-trigger) ---
# This function is triggered by Event Grid events from ADLS Gen2.
# It orchestrates the initial data scanning and classification process.
resource "azurerm_function_app" "event_grid_trigger_function" {
  name                       = "${var.project_name}-egtrigger-func-${var.environment}"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  app_service_plan_id        = var.function_app_service_plan_id
  storage_account_name       = var.function_app_storage_account_name
  storage_account_access_key = data.azurerm_storage_account.function_app_storage.primary_access_key
  os_type                    = "Linux" # Or "Windows"
  version                    = "~4"    # Use Function App V4 runtime
  https_only                 = true    # Enforce HTTPS

  # Ensure Function App has a System-Assigned Managed Identity
  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"    = "node" # For TypeScript/JavaScript functions
    "WEBSITE_RUN_FROM_PACKAGE"    = "1"    # Best practice for deployment via zip
    "ADLS_GEN2_ACCOUNT_NAME"      = var.adls_gen2_account_name
    "ADLS_GEN2_FILESYSTEM_NAME"   = "${var.project_name}-data" # Main filesystem name
    "EVENT_HUB_NAMESPACE_NAME"    = azurerm_eventhub_namespace.main.name
    "EVENT_HUB_NAME"              = azurerm_eventhub.main.name
    "EVENT_HUB_CONNECTION_STRING" = azurerm_eventhub_namespace.main.default_primary_connection_string
    # You will add other environment variables here to pass IDs/endpoints of other services (e.g., Synapse, AML, Cosmos DB)
  }

  site_config {
    # VNet Integration for Function App
    ip_restriction {
      virtual_network_subnet_id = var.function_subnet_id # Integrate with the function subnet
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Data source for the Function App's storage account key
data "azurerm_storage_account" "function_app_storage" {
  name                = var.function_app_storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# --- Role Assignments for Function App Managed Identity ---
# The 'event-grid-trigger' Function App needs permissions:
# 1. To read/list from ADLS Gen2 (to access the new file)
# 2. To send messages to Event Hubs (to forward processed events)
# 3. To potentially trigger Synapse/Azure ML jobs.

resource "azurerm_role_assignment" "func_adls_reader" {
  scope                = "/subscriptions/${data.azurerm_subscription.current.id}/resourceGroups/${data.azurerm_resource_group.main.name}/providers/Microsoft.Storage/storageAccounts/${var.adls_gen2_account_name}"
  role_definition_name = "Storage Blob Data Reader" # For reading blobs from ADLS Gen2
  principal_id         = azurerm_function_app.event_grid_trigger_function.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_event_hub_sender" {
  scope                = azurerm_eventhub_namespace.main.id
  role_definition_name = "Azure Event Hubs Data Sender" # For sending messages to Event Hub
  principal_id         = azurerm_function_app.event_grid_trigger_function.identity[0].principal_id
}