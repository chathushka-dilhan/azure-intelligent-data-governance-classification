# This Terraform module sets up a secure network environment in Azure.
# It includes a Resource Group, Virtual Network, Subnets, Network Security Groups (NSGs),
# and optional Route Tables for advanced routing scenarios.

# --- Resource Group ---
# All network resources and potentially other core services will be deployed into this central resource group.
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg-${var.environment}"
  location = var.location
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# --- Virtual Network (VNet) ---
# The backbone of our secure network environment.
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_cidr]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# --- Subnets ---
# Dynamically create subnets based on the provided CIDR map.
# Each subnet will have an associated Network Security Group (NSG).
resource "azurerm_subnet" "main" {
  for_each = var.subnet_cidrs

  name                 = "${var.project_name}-snet-${each.key}-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]

  # IMPORTANT: Subnet delegation for specific services
  # This needs to be configured based on which services will use this subnet.
  dynamic "delegation" {
    for_each = contains(["function-subnet", "data-subnet", "synapse-managed-vnet-subnet"], each.key) ? [1] : []
    content {
      name = "${each.key}-delegation"
      service_delegation {
        # Service delegation for Function App subnet
        name = each.key == "function-subnet" ? "Microsoft.Web/serverFarms" : (
          # Service delegation for Cosmos DB VNet integration (if data-subnet is used for it)
          each.key == "data-subnet" ? "Microsoft.DocumentDB/virtualNetworks" : (
            # Service delegation for Synapse Managed VNet
            each.key == "synapse-managed-vnet-subnet" ? "Microsoft.Sql/managedInstances" : null # Or 'Microsoft.Synapse/workspaces' for some scenarios
          )
        )
        # Add actions if required by the service delegation
        # actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

# --- Network Security Groups (NSGs) ---
# Create an NSG for each subnet defined in subnet_cidrs.
resource "azurerm_network_security_group" "main" {
  for_each = var.subnet_cidrs

  name                = "${var.project_name}-nsg-${each.key}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Create NSG Association for each subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = var.subnet_cidrs

  subnet_id                 = azurerm_subnet.main[each.key].id
  network_security_group_id = azurerm_network_security_group.main[each.key].id
}

# --- Route Tables (Optional, for advanced routing) ---
# If you need custom routing (e.g., forcing traffic through an NVA or VPN Gateway),
# you would define Route Tables here and associate them with subnets.
/*
resource "azurerm_route_table" "main" {
  name                = "${var.project_name}-rt-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  disable_bgp_route_propagation = false # Set to true if you don't want routes propagated to VPN/ExpressRoute

  route {
    name                   = "default-route"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "Internet" # Or VirtualAppliance, VnetLocal, VirtualNetworkGateway
    # next_hop_in_ip_address = "10.0.0.4" # If next_hop_type is VirtualAppliance
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Associate a subnet with the route table
resource "azurerm_subnet_route_table_association" "main" {
  # For each subnet you want to associate
  subnet_id      = azurerm_subnet.main["app-subnet"].id
  route_table_id = azurerm_route_table.main.id
}
*/