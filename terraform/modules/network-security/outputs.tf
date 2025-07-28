output "resource_group_name" {
  description = "Name of the main resource group created by this module."
  value       = azurerm_resource_group.main.name
}

output "vnet_name" {
  description = "Name of the main Virtual Network."
  value       = azurerm_virtual_network.main.name
}

output "vnet_id" {
  description = "ID of the main Virtual Network."
  value       = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "Map of subnet names to their resource IDs."
  value       = { for k, v in azurerm_subnet.main : k => v.id }
}

output "subnet_names" {
  description = "Map of subnet names to their names."
  value       = { for k, v in azurerm_subnet.main : k => v.name }
}

output "nsg_ids" {
  description = "Map of subnet names to their NSG resource IDs."
  value       = { for k, v in azurerm_network_security_group.main : k => v.id }
}
