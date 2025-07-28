# This Terraform module deploys the metadata governance components for Azure Data Lake Sentinel.

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Data source for the Function App's service plan
data "azurerm_app_service_plan" "function_app_plan" {
  name                = var.function_app_service_plan_name
  resource_group_name = data.azurerm_resource_group.main.name
  id                  = var.function_app_service_plan_id
}

# Data source for the Function App's storage account key
data "azurerm_storage_account" "function_app_storage" {
  name                = var.function_app_storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# --- Azure Function App (metadata-updater) ---
# This function updates Cosmos DB with classification results.
resource "azurerm_function_app" "metadata_updater_function" {
  name                       = "${var.project_name}-meta-update-func-${var.environment}"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  app_service_plan_id        = data.azurerm_app_service_plan.function_app_plan.id
  storage_account_name       = data.azurerm_storage_account.function_app_storage.name
  storage_account_access_key = data.azurerm_storage_account.function_app_storage.primary_access_key
  os_type                    = "Linux"
  version                    = "~4" # Function App V4 runtime for Node.js
  https_only                 = true

  identity {
    type = "SystemAssigned" # Managed Identity for Cosmos DB access
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"   = "node"
    "WEBSITE_RUN_FROM_PACKAGE"   = "1"
    "COSMOSDB_ENDPOINT"          = var.cosmos_db_endpoint
    "COSMOSDB_PRIMARY_KEY"       = var.cosmos_db_primary_key
    "COSMOSDB_DATABASE_NAME"     = var.cosmos_db_database_name
    "COSMOSDB_CONTAINER_NAME"    = var.cosmos_db_container_name
    "LOGIC_APP_HTTP_TRIGGER_URL" = azurerm_logic_app_workflow.notifier_logic_app.access_endpoint # Pass Logic App URL
    # Add other environment variables for secrets or configs
  }

  site_config {
    ip_restriction = {
      subnet_id = var.function_subnet_id
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# --- Role Assignments for Metadata Updater Function Managed Identity ---
# Needs permissions to write to Cosmos DB.
resource "azurerm_role_assignment" "func_cosmosdb_contributor" {
  scope                = "/subscriptions/${data.azurerm_subscription.current.id}/resourceGroups/${data.azurerm_resource_group.main.name}/providers/Microsoft.DocumentDB/databaseAccounts/${var.cosmos_db_account_name}"
  role_definition_name = "Cosmos DB Built-in Data Contributor" # For data operations on Cosmos DB
  principal_id         = azurerm_function_app.metadata_updater_function.identity[0].principal_id
}

data "azurerm_subscription" "current" {}


# --- Azure Logic App for Notifications ---
# Triggered by the metadata-updater function for alerts on highly sensitive data,
# or for orchestrating policy enforcement based on classification.
resource "azurerm_logic_app_workflow" "notifier_logic_app" {
  name                = "${var.logic_app_name}-${var.environment}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  workflow_parameters = {}

  # Define the Logic App workflow using JSON.
  # This is a basic HTTP Request trigger, and an email action.
  # You would expand this with actual Teams, ITSM, or Azure Automation connectors.
  workflow_schema = jsonencode({
    "$schema"        = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "contentVersion" = "1.0.0.0",
    "parameters"     = {},
    "triggers" = {
      "manual" = {
        "type" = "Request",
        "kind" = "Http",
        "inputs" = {
          "schema" = {
            "type" = "object",
            "properties" = {
              "filePath"         = { "type" : "string" },
              "classification"   = { "type" : "string" },
              "confidence"       = { "type" : "number" },
              "message"          = { "type" : "string" },
              "detectionDetails" = { "type" : "string" }
            }
          }
        }
      }
    },
    "actions" = {
      "Send_Email_(V2)" = { # Example action - requires an email connection to be manually authorized
        "runAfter" = {},
        "type"     = "ApiConnection",
        "inputs" = {
          "host" = {
            "connection" = {
              "name" = "@parameters('$connections')['office365']['connectionId']" # Placeholder for connection
            }
          },
          "method" = "post",
          "path"   = "/v2/Mail",
          "queries" = {
            "mailType" = "Html"
          },
          "body" = {
            "To"      = var.notification_email,
            "Subject" = "Azure Data Governance Alert: Sensitive Data Detected - @{triggerBody()?['classification']}",
            "Body"    = "<h3>Sensitive Data Detection Alert</h3><p><strong>File Path:</strong> @{triggerBody()?['filePath']}</p><p><strong>Classification:</strong> <span style='color: @{if(equals(triggerBody()?['classification'], 'PII'), 'red', if(equals(triggerBody()?['classification'], 'Confidential'), 'orange', 'green'))}'>@{triggerBody()?['classification']}</span></p><p><strong>Confidence:</strong> @{triggerBody()?['confidence']}</p><p><strong>Message:</strong> @{triggerBody()?['message']}</p><p><strong>Detection Details:</strong> <pre>@{triggerBody()?['detectionDetails']}</pre></p>"
          }
        }
      }
      # Add other actions like Microsoft Teams webhook, ServiceNow integration, Azure Automation runbook trigger etc.
    }
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}