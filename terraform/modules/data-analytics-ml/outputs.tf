output "synapse_workspace_name" {
  description = "Name of the Azure Synapse Analytics Workspace."
  value       = azurerm_synapse_workspace.main.name
}

output "synapse_workspace_id" {
  description = "ID of the Azure Synapse Analytics Workspace."
  value       = azurerm_synapse_workspace.main.id
}

output "azure_ml_workspace_name" {
  description = "Name of the Azure Machine Learning Workspace."
  value       = azurerm_machine_learning_workspace.main.name
}

output "azure_ml_workspace_id" {
  description = "ID of the Azure Machine Learning Workspace."
  value       = azurerm_machine_learning_workspace.main.id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster for ML inference."
  value       = azurerm_kubernetes_cluster.aks_ml_cluster.name
}