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

variable "adls_gen2_filesystem_id" {
  description = "ID of the primary filesystem (container) in ADLS Gen2."
  type        = string
}

variable "adls_gen2_filesystem_name" {
  description = "Name of the primary filesystem (container) in ADLS Gen2."
  type        = string
}

variable "virtual_network_name" {
  description = "Name of the virtual network where resources will be deployed."
  type        = string
}

variable "synapse_managed_vnet_subnet_name" {
  description = "Name of the subnet delegated to Synapse Managed VNet."
  type        = string
}

variable "synapse_managed_vnet_subnet_id" {
  description = "ID of the subnet delegated to Synapse Managed VNet."
  type        = string
}

variable "ml_subnet_id" {
  description = "ID of the subnet for Azure ML compute and AKS nodes."
  type        = string
}

variable "synapse_workspace_name" {
  description = "Name for the Azure Synapse Analytics Workspace."
  type        = string
}

variable "azure_ml_workspace_name" {
  description = "Name for the Azure Machine Learning Workspace."
  type        = string
}