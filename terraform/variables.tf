# --- General Project Variables ---
variable "project_name" {
  description = "A unique prefix for all resources to ensure naming consistency."
  type        = string
  default     = "adlsentinel"
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
  default     = "East US" # Customize to your preferred Azure region
}

variable "environment" {
  description = "The environment tag for resources (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "The owner tag for resources (e.g., team name)."
  type        = string
  default     = "data-governance-team"
}

# --- Network Security Variables ---
variable "vnet_cidr" {
  description = "The CIDR block for the main Virtual Network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "A map of subnet names to their CIDR blocks."
  type        = map(string)
  default = {
    "app-subnet"                = "10.0.0.0/24"
    "data-subnet"               = "10.0.1.0/24" # For ADLS PE, Cosmos DB PE/VNet integration
    "ml-subnet"                 = "10.0.2.0/24" # For Azure ML compute
    "function-subnet"           = "10.0.3.0/24" # For Azure Functions VNet integration
    "synapse-managed-vnet-subnet" = "10.0.4.0/24" # For Synapse Managed VNet
  }
}

variable "synapse_managed_vnet_subnet_name" {
  description = "The name of the subnet for Azure Synapse Managed VNet."
  type        = string
  default     = "synapse-managed-vnet-subnet"
}

# --- Core Azure Services Variables ---
variable "cosmos_db_account_name" {
  description = "Name for the Azure Cosmos DB account. Must be globally unique."
  type        = string
  default     = "adlsentinelcosmosdb" # Will append random string
}

variable "cosmos_db_database_name" {
  description = "Name for the Cosmos DB SQL API database."
  type        = string
  default     = "DataGovernanceDB"
}

variable "cosmos_db_container_name" {
  description = "Name for the Cosmos DB SQL API container (collection)."
  type        = string
  default     = "ClassificationMetadata"
}

variable "function_app_service_plan_name" {
  description = "Name for the Azure Function App Service Plan."
  type        = string
  default     = "asp-adlsentinel"
}

variable "function_app_storage_account_name" {
  description = "Base name for the Azure Function App's storage account. Must be globally unique."
  type        = string
  default     = "stadlsentinelfunc" # Will append random string
}

# --- Data Ingestion & Eventing Variables ---
variable "event_hub_namespace_name" {
  description = "Name for the Azure Event Hubs Namespace."
  type        = string
  default     = "ehns-adlsentinel"
}

variable "event_hub_name" {
  description = "Name for the Azure Event Hub."
  type        = string
  default     = "datalake-events"
}

# --- Data Analytics & ML Variables ---
variable "synapse_workspace_name" {
  description = "Name for the Azure Synapse Analytics Workspace."
  type        = string
  default     = "syn-adlsentinel"
}

variable "azure_ml_workspace_name" {
  description = "Name for the Azure Machine Learning Workspace."
  type        = string
  default     = "aml-adlsentinel"
}

# --- AI & Cognitive Services Variables ---
variable "open_ai_account_name" {
  description = "Name for the Azure OpenAI Service account. Must be globally unique."
  type        = string
  default     = "openai-adlsentinel" # Will append random string
}

variable "cognitive_services_account_name" {
  description = "Name for the Azure Cognitive Services account. Must be globally unique."
  type        = string
  default     = "cogsvc-adlsentinel" # Will append random string
}

# --- Metadata Governance Variables ---
variable "logic_app_name" {
  description = "Name for the Azure Logic App for notifications."
  type        = string
  default     = "logic-adlsentinel-notifier"
}

variable "notification_email" {
  description = "Email address for sending Logic App notifications."
  type        = string
  default     = "your.email@example.com" # IMPORTANT: Change this!
}