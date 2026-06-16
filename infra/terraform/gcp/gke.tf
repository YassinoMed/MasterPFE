# Terraform GCP GKE — SecureRAG Hub Multi-Cloud
# Feature flag: ENABLE_GCP_GKE=true

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

variable "cluster_name" { default = "securerag-gke" }
variable "region" { default = "europe-west1" }
variable "node_count" { default = 3 }
variable "enable_gcp" { default = false }

resource "google_container_cluster" "securerag" {
  count = var.enable_gcp ? 1 : 0
  name     = var.cluster_name
  location = var.region
  remove_default_node_pool = true
  initial_node_pool { name = "temp" }
}

resource "google_container_node_pool" "securerag" {
  count = var.enable_gcp ? 1 : 0
  name       = "${var.cluster_name}-workers"
  cluster    = google_container_cluster.securerag[0].name
  location   = var.region
  node_count = var.node_count
  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
  }
}

# Rollback: terraform destroy -target=google_container_node_pool.securerag
