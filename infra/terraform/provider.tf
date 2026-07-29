# Terraform — Provider Configuration for Multi-Cloud (AWS, Azure, GCP)
# Chaque provider est conditionnellement activé via feature flags.

terraform {
  required_version = ">= 1.5"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# ── Kind (local) ─────────────────────────────────────────────────────────
provider "kind" {}

provider "kubernetes" {
  host                   = try(kind_cluster.secure_rag.endpoint, "https://127.0.0.1:6443")
  client_certificate     = try(kind_cluster.secure_rag.client_certificate, "")
  client_key             = try(kind_cluster.secure_rag.client_key, "")
  cluster_ca_certificate = try(kind_cluster.secure_rag.cluster_ca_certificate, "")
}

provider "kubectl" {
  config_path = "~/.kube/config"
  host                   = try(kind_cluster.secure_rag.endpoint, "https://127.0.0.1:6443")
  client_certificate     = try(kind_cluster.secure_rag.client_certificate, "")
  client_key             = try(kind_cluster.secure_rag.client_key, "")
  cluster_ca_certificate = try(kind_cluster.secure_rag.cluster_ca_certificate, "")
  load_config_file       = true
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    host                   = try(kind_cluster.secure_rag.endpoint, "https://127.0.0.1:6443")
    client_certificate     = try(kind_cluster.secure_rag.client_certificate, "")
    client_key             = try(kind_cluster.secure_rag.client_key, "")
    cluster_ca_certificate = try(kind_cluster.secure_rag.cluster_ca_certificate, "")
  }
}

# ── AWS ──────────────────────────────────────────────────────────────────
provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock"
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = "SecureRAG-Hub"
      CostCenter  = var.cost_center
    }
  }
}

# ── Azure ────────────────────────────────────────────────────────────────
provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}

provider "azuread" {
  use_cli = false
}

# ── GCP ──────────────────────────────────────────────────────────────────
provider "google" {
  region                = var.gcp_region
  project               = var.gcp_project_id != "" ? var.gcp_project_id : "securerag-mock-project"
  credentials           = "{\"type\": \"service_account\", \"project_id\": \"securerag-mock-project\"}"
  user_project_override = false
}

provider "tls" {}

provider "random" {}
