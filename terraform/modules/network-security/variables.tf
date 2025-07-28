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

variable "vnet_cidr" {
  description = "The CIDR block for the main Virtual Network."
  type        = string
}

variable "subnet_cidrs" {
  description = "A map of subnet names to their CIDR blocks."
  type        = map(string)
}