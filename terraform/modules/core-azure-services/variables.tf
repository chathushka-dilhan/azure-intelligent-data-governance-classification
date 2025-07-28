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

variable "virtual_network_name" {
  description = "Name of the virtual network where resources will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet names to their resource IDs, from network-security module."
  type        = map(string)
}

variable "adls_gen2_account_name" {
  description = "Base name for the Azure Data Lake Storage Gen2 account."
  type        = string
}

variable "cosmos_db_account_name" {
  description = "Name for the Azure Cosmos DB account."
  type        = string
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
  description = "Name for the Azure Function App Service Plan."
  type        = string
}

variable "function_app_storage_account_name" {
  description = "Base name for the Azure Function App's storage account."
  type        = string
}