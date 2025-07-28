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

variable "adls_gen2_account_name" {
  description = "Name of the Azure Data Lake Storage Gen2 account."
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

variable "event_hub_namespace_name" {
  description = "Name for the Azure Event Hubs Namespace."
  type        = string
}

variable "event_hub_name" {
  description = "Name for the Azure Event Hub."
  type        = string
}