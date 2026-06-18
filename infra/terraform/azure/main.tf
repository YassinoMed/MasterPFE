# Terraform — Azure AKS Cluster (Standalone Configuration)
# Usage: terraform -chdir=infra/terraform/azure init && terraform -chdir=infra/terraform/azure apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    storage_account_name = "secureragterraformstate"
    container_name       = "tfstate"
    key                  = "azure-aks/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

provider "azuread" {}

variable "cluster_name" {
  type        = string
  default     = "securerag"
  description = "Nom de base du cluster"
}

variable "azure_location" {
  type        = string
  default     = "westeurope"
  description = "Localisation Azure"
}

variable "cluster_version" {
  type        = string
  default     = "1.31"
  description = "Version Kubernetes"
}

variable "node_instance_type" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "Type de VM pour les nœuds"
}

variable "node_min_size" {
  type        = number
  default     = 2
  description = "Nombre minimum de nœuds"
}

variable "node_max_size" {
  type        = number
  default     = 5
  description = "Nombre maximum de nœuds"
}

variable "authorized_ip_ranges" {
  type        = list(string)
  default     = []
  description = "Plages IP autorisées"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Environnement"
}

variable "cost_center" {
  type        = string
  default     = "securerag-hub"
  description = "Centre de coût"
}
