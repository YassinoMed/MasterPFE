# Terraform — GCP GKE Cluster (Standalone Configuration)
# Usage: terraform -chdir=infra/terraform/gcp init && terraform -chdir=infra/terraform/gcp apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  backend "gcs" {
    bucket = "securerag-terraform-state"
    prefix = "gcp-gke"
  }
}

provider "google" {
  region = var.gcp_region
}

variable "cluster_name" {
  type        = string
  default     = "securerag"
  description = "Nom de base du cluster"
}

variable "gcp_region" {
  type        = string
  default     = "europe-west1"
  description = "Région GCP"
}

variable "gcp_project_id" {
  type        = string
  description = "ID du projet GCP"
}

variable "cluster_version" {
  type        = string
  default     = "1.31"
  description = "Version Kubernetes"
}

variable "node_instance_type" {
  type        = string
  default     = "e2-standard-2"
  description = "Type de machine pour les nœuds"
}

variable "node_min_size" {
  type        = number
  default     = 2
  description = "Nombre minimum de nœuds"
}

variable "node_max_size" {
  type        = number
  default     = 6
  description = "Nombre maximum de nœuds"
}

variable "private_cluster" {
  type        = bool
  default     = false
  description = "Cluster privé"
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
