# Specify the required Terraform version
terraform {
    required_version = ">= 1.12.2" # Ensure compatibility with modern Terraform features

    # Configure the Azure Blob Storage backend for Terraform state management
    # This is crucial for collaborative development and state persistence.
    # IMPORTANT: You'll need to create this Storage Account and Container manually ONCE
    # before running `terraform init` for the first time.
    backend "azurerm" {
        resource_group_name  = "tfstate-rg-adlsentinel" # Customize this RG name!
        storage_account_name = "tfstateadlsentinel"    # Customize this SA name!
        container_name       = "tfstate"
        key                  = "azure-data-lake-sentinel.tfstate"
    }

    # Specify the required provider versions
    required_providers {
        azurerm = {
            source  = "hashicorp/azurerm"
            version = "~> 3.0" # Use a compatible version range
        }
        random = { # Used for generating unique names
            source  = "hashicorp/random"
            version = "~> 3.0"
        }
    }
}

