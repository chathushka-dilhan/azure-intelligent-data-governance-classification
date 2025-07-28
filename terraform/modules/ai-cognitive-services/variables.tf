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

variable "open_ai_account_name" {
  description = "Name for the Azure OpenAI Service account."
  type        = string
}

variable "cognitive_services_account_name" {
  description = "Name for the Azure Cognitive Services account."
  type        = string
}