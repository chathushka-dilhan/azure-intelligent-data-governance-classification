variable "project_name" {
  description = "A unique prefix for resources."
  type        = string
}

variable "location" {
  description = "The Azure region."
  type        = string
}

variable "environment" {
  description = "The environment tag."
  type        = string
}

variable "owner" {
  description = "The owner tag."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group created by the network-security module."
  type        = string
}

variable "cosmos_db_endpoint" {
  description = "Endpoint URL for the Azure Cosmos DB account."
  type        = string
}

variable "cosmos_db_primary_key" {
  description = "Primary key for the Azure Cosmos DB account."
  type        = string
  sensitive   = true
}

variable "cosmos_db_database_name" {
  description = "Name for the Cosmos DB SQL API database."
  type        = string
}

variable "cosmos_db_container_name" {
  description = "Name for the Cosmos DB SQL API container."
  type        = string
}

variable "function_app_service_plan_name" {
  description = "Name of the Azure Function App Service Plan."
  type        = string
}

variable "function_app_service_plan_id" {
  description = "ID of the Azure Function App Service Plan."
  type        = string
}

variable "function_app_storage_account_name" {
  description = "Name of the Azure Function App's storage account."
  type        = string
}

variable "function_subnet_id" {
  description = "ID of the subnet for Function App VNet integration."
  type        = string
}

variable "logic_app_name" {
  description = "Name for the Azure Logic App for notifications."
  type        = string
}

variable "notification_email" {
  description = "Email address for sending Logic App notifications."
  type        = string
}