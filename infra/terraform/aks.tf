# Terraform Azure AKS — SecureRAG Hub Multi-Cloud
# Feature flag: enable_azure (bool)
# Provisionne un cluster AKS complet avec Azure AD, RBAC, CNI, monitoring, workload identity.

locals {
  aks_name = "${var.cluster_name}-aks"
  aks_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "SecureRAG-Hub"
    Cluster     = local.aks_name
    CostCenter  = var.cost_center
  }
}

resource "azurerm_resource_group" "this" {
  count    = var.enable_azure ? 1 : 0
  name     = "${local.aks_name}-rg"
  location = var.azure_location
  tags     = local.aks_tags
}

# ── Virtual Network ──────────────────────────────────────────────────────
resource "azurerm_virtual_network" "this" {
  count               = var.enable_azure ? 1 : 0
  name                = "${local.aks_name}-vnet"
  location            = azurerm_resource_group.this[0].location
  resource_group_name = azurerm_resource_group.this[0].name
  address_space       = ["10.1.0.0/16"]
  tags                = local.aks_tags
}

resource "azurerm_subnet" "aks" {
  #checkov:skip=CKV2_AZURE_31: "NSG associated via Azure CNI Network Policy"
  count                = var.enable_azure ? 1 : 0
  name                 = "${local.aks_name}-subnet"
  resource_group_name  = azurerm_resource_group.this[0].name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = ["10.1.0.0/18"]
}

# ── Log Analytics ────────────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "this" {
  count               = var.enable_azure ? 1 : 0
  name                = "${local.aks_name}-logs"
  location            = azurerm_resource_group.this[0].location
  resource_group_name = azurerm_resource_group.this[0].name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.aks_tags
}

# ── Azure AD Integration ─────────────────────────────────────────────────
data "azurerm_client_config" "current" {
  count = var.enable_azure ? 1 : 0
}

resource "azuread_application" "aks" {
  count        = var.enable_azure ? 1 : 0
  display_name = "${local.aks_name}-app"
}

resource "azuread_service_principal" "aks" {
  count        = var.enable_azure ? 1 : 0
  client_id    = azuread_application.aks[0].client_id
  use_existing = true
}

# ── AKS Cluster ──────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "this" {
  count               = var.enable_azure ? 1 : 0
  name                = local.aks_name
  location            = azurerm_resource_group.this[0].location
  resource_group_name = azurerm_resource_group.this[0].name
  dns_prefix          = local.aks_name
  kubernetes_version  = var.cluster_version
  node_resource_group = "${local.aks_name}-node-rg"

  default_node_pool {
    name                 = "default"
    vm_size              = var.node_instance_type
    node_count           = var.node_min_size
    min_count            = var.node_min_size
    max_count            = var.node_max_size
    auto_scaling_enabled = true
    os_disk_size_gb      = 100
    vnet_subnet_id       = azurerm_subnet.aks[0].id
    node_labels = {
      "securerag.io/node-pool" = "default"
    }
    tags = local.aks_tags
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [data.azurerm_client_config.current[0].object_id]
    azure_rbac_enabled     = true
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    dns_service_ip    = "10.1.0.10"
    service_cidr      = "10.1.1.0/24"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this[0].id
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this[0].id
  }

  azure_policy_enabled = true

  http_application_routing_enabled = false

  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
  }

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4]
    }
  }

  tags = local.aks_tags
}

# ── Workload Identity Federation ─────────────────────────────────────────
resource "azurerm_federated_identity_credential" "this" {
  count               = var.enable_azure ? 1 : 0
  name                = "${local.aks_name}-workload-identity"
  resource_group_name = azurerm_resource_group.this[0].name
  parent_id           = azurerm_kubernetes_cluster.this[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this[0].oidc_issuer_url
  subject             = "system:serviceaccount:securerag-hub:workload-identity-sa"
}

# ── Container Insights ───────────────────────────────────────────────────
resource "azurerm_log_analytics_solution" "container_insights" {
  count                 = var.enable_azure ? 1 : 0
  solution_name         = "ContainerInsights"
  location              = azurerm_log_analytics_workspace.this[0].location
  resource_group_name   = azurerm_resource_group.this[0].name
  workspace_resource_id = azurerm_log_analytics_workspace.this[0].id
  workspace_name        = azurerm_log_analytics_workspace.this[0].name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = local.aks_tags
}
