# Terraform module for Azure Data Analytics and Machine Learning
# This module sets up an Azure Synapse Analytics workspace, Spark pool, and Azure Machine Learning
# workspace with necessary networking and security configurations.

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Data source for the ADLS Gen2 Filesystem
data "azurerm_storage_container" "adls_gen2_filesystem" {
  name = var.adls_gen2_filesystem_name
  id   = var.adls_gen2_filesystem_id
}

# Data source for the ADLS Gen2 Storage Account
data "azurerm_storage_account" "adls_gen2_account" {
  name                = data.azurerm_storage_container.adls_gen2_filesystem.storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name # Assuming it's in the same RG
}

# --- Azure Synapse Analytics Workspace ---
# Unified analytics platform for data warehousing, data integration, and big data processing.
resource "azurerm_synapse_workspace" "main" {
  name                                 = "${var.synapse_workspace_name}-${var.environment}"
  resource_group_name                  = data.azurerm_resource_group.main.name
  location                             = data.azurerm_resource_group.main.location
  storage_data_lake_gen2_filesystem_id = var.adls_gen2_filesystem_id
  sql_administrator_login              = "synapseadmin"                                  # Replace with secure admin login
  sql_administrator_login_password     = random_string.synapse_sql_admin_password.result # Generate strong password

  # Enable Managed Virtual Network for enhanced security
  managed_virtual_network_enabled = true
  managed_resource_group_name     = "${azurerm_synapse_workspace.main.name}-managed-rg"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Generate a strong password for Synapse SQL Administrator
resource "random_string" "synapse_sql_admin_password" {
  length  = 16
  special = true
  upper   = true
  numeric = true
}

# Private Endpoint for Synapse Workspace (for SQL and Dev endpoints)
resource "azurerm_private_endpoint" "synapse_sql_pe" {
  name                = "${var.project_name}-syn-sql-pe-${var.environment}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  subnet_id           = var.synapse_managed_vnet_subnet_id # Or a dedicated PE subnet

  private_service_connection {
    name                           = "${var.project_name}-syn-sql-pls-conn"
    private_connection_resource_id = azurerm_synapse_workspace.main.id
    is_manual_connection           = false
    subresource_names              = ["sql"] # Connect to SQL endpoint
  }

  private_dns_zone_group {
    name                 = "${var.project_name}-syn-sql-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.synapse_sql_dns_zone.id]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "azurerm_private_endpoint" "synapse_dev_pe" {
  name                = "${var.project_name}-syn-dev-pe-${var.environment}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  subnet_id           = var.synapse_managed_vnet_subnet_id # Or a dedicated PE subnet

  private_service_connection {
    name                           = "${var.project_name}-syn-dev-pls-conn"
    private_connection_resource_id = azurerm_synapse_workspace.main.id
    is_manual_connection           = false
    subresource_names              = ["dev"] # Connect to Dev endpoint
  }

  private_dns_zone_group {
    name                 = "${var.project_name}-syn-dev-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.synapse_dev_dns_zone.id]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}


# Private DNS Zone for Synapse SQL endpoint
resource "azurerm_private_dns_zone" "synapse_sql_dns_zone" {
  name                = "privatelink.sql.azuresynapse.net"
  resource_group_name = data.azurerm_resource_group.main.name
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Private DNS Zone for Synapse Dev endpoint
resource "azurerm_private_dns_zone" "synapse_dev_dns_zone" {
  name                = "privatelink.dev.azuresynapse.net"
  resource_group_name = data.azurerm_resource_group.main.name
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Link Private DNS Zones to Synapse Managed VNet (if applicable) or other VNets
resource "azurerm_private_dns_virtual_network_link" "synapse_sql_vnet_link" {
  name                  = "${var.project_name}-syn-sql-vnet-link-${var.environment}"
  resource_group_name   = data.azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.synapse_sql_dns_zone.name
  virtual_network_id    = data.azurerm_subnet.synapse_managed_vnet_subnet.virtual_network_id
  registration_enabled  = false
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "azurerm_private_dns_virtual_network_link" "synapse_dev_vnet_link" {
  name                  = "${var.project_name}-syn-dev-vnet-link-${var.environment}"
  resource_group_name   = data.azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.synapse_dev_dns_zone.name
  virtual_network_id    = data.azurerm_subnet.synapse_managed_vnet_subnet.virtual_network_id
  registration_enabled  = false
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Data source for the Synapse Managed VNet subnet
data "azurerm_subnet" "synapse_managed_vnet_subnet" {
  name                 = var.synapse_managed_vnet_subnet_name
  id                   = var.synapse_managed_vnet_subnet_id
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
}

# --- Azure Synapse Spark Pool ---
# Provides scalable compute for Spark jobs (e.g., text extraction, chunking, batch classification).
resource "azurerm_synapse_spark_pool" "main" {
  name                 = "${var.project_name}-sparkpool-${var.environment}"
  synapse_workspace_id = azurerm_synapse_workspace.main.id
  node_count           = 3 # Adjust based on workload needs
  node_size_family     = "MemoryOptimized"
  node_size            = "Small" # Small, Medium, Large etc.
  auto_scale {
    min_node_count = 3
    max_node_count = 10
  }
  auto_pause {
    delay_in_minutes = 30
  }
  spark_version = "3.3" # Or other supported versions

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# --- Azure Machine Learning Workspace ---
# Central hub for ML lifecycle (experimentation, training, deployment).
resource "azurerm_machine_learning_workspace" "main" {
  name                    = "${var.azure_ml_workspace_name}-${var.environment}"
  resource_group_name     = data.azurerm_resource_group.main.name
  location                = data.azurerm_resource_group.main.location
  application_insights_id = azurerm_application_insights.main.id              # Dependency
  key_vault_id            = azurerm_key_vault.main.id                         # Dependency
  storage_account_id      = data.azurerm_storage_account.adls_gen2_account.id # Use main ADLS Gen2
  identity {
    type = "SystemAssigned" # Required for some AML functionalities
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Required dependencies for Azure ML Workspace
resource "azurerm_application_insights" "main" {
  name                = "${var.project_name}-appins-${var.environment}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  application_type    = "Web" # Or other suitable type
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "azurerm_key_vault" "main" {
  name                       = "${var.project_name}-kv-${var.environment}"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7     # Minimum 7 days
  purge_protection_enabled   = false # Enable for production (prevents immediate purge)
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Data source for current Azure Client Configuration (Tenant ID)
data "azurerm_client_config" "current" {}


# --- Azure Machine Learning Compute Instance (for Notebooks) ---
# A managed development environment for data scientists.
# You can also use Compute Clusters for training jobs.
resource "azurerm_machine_learning_compute_instance" "dev_instance" {
  name                          = "${var.project_name}-ml-ci-${var.environment}"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.main.id
  virtual_machine_size          = "Standard_DS3_v2" # Adjust VM size as needed

  # VNet integration for ML compute (recommended for secure access to data)
  subnet_resource_id = var.ml_subnet_id

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# --- Azure Kubernetes Service (AKS) or Azure Container Instances (ACI) for AML Endpoints ---
# Choose AKS for production-grade, scalable inference, ACI for quick dev/test deployments.
# Here we'll configure AKS as a general-purpose compute target for AML endpoints.
resource "azurerm_kubernetes_cluster" "aks_ml_cluster" {
  name                = "${var.project_name}-aksml-${var.environment}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}-aksml"
  kubernetes_version  = "1.27" # Specify a compatible version

  default_node_pool {
    name           = "default"
    node_count     = 2 # Min nodes
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = var.ml_subnet_id # Deploy AKS nodes into the ML subnet
  }

  identity {
    type = "SystemAssigned" # Managed Identity for AKS
  }

  network_profile {
    network_plugin = "azure" # CNI for advanced networking
    service_cidr   = "10.10.0.0/16"
    dns_service_ip = "10.10.0.10"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}

# Attach AKS cluster to Azure ML workspace as an inference compute target
resource "azurerm_machine_learning_compute_cluster" "aks_compute_target" {
  name                          = "${var.project_name}-aks-compute-${var.environment}"
  location                      = data.azurerm_resource_group.main.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.main.id
  vm_priority                   = "Dedicated" # Dedicated VMs for stable inference
  vm_size                       = "Standard_DS2_v2"
  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 3
    scale_down_nodes_after_idle_duration = "PT30M"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
  }
}