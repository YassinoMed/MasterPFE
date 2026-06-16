# Terraform Azure AKS — SecureRAG Hub Multi-Cloud
# Feature flag: ENABLE_AZURE_AKS=true

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

variable "cluster_name" { default = "securerag-aks" }
variable "location" { default = "westeurope" }
variable "node_count" { default = 3 }
variable "enable_azure" { default = false }

resource "azurerm_kubernetes_cluster" "securerag" {
  count = var.enable_azure ? 1 : 0
  name                = var.cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.securerag[0].name
  dns_prefix          = var.cluster_name
  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = "Standard_D4s_v3"
  }
  identity { type = "SystemAssigned" }
}

# Rollback: terraform destroy -target=azurerm_kubernetes_cluster.securerag
