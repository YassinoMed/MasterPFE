# Terraform GCP GKE — SecureRAG Hub Multi-Cloud
# Feature flag: enable_gcp (bool)
# Provisionne un cluster GKE régional avec Workload Identity, Cloud Ops, shielded nodes.

locals {
  gke_name  = "${var.cluster_name}-gke"
  gke_zones = ["${var.gcp_region}-a", "${var.gcp_region}-b", "${var.gcp_region}-c"]
  gke_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "securerag-hub"
    cluster     = local.gke_name
    cost_center = var.cost_center
  }
}

data "google_project" "current" {
  count = var.enable_gcp ? 1 : 0
}

# ── VPC ──────────────────────────────────────────────────────────────────
resource "google_compute_network" "this" {
  #checkov:skip=CKV2_GCP_18: "Firewall rules configured by GKE network engine"
  count                   = var.enable_gcp ? 1 : 0
  name                    = "${local.gke_name}-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "this" {
  count         = var.enable_gcp ? 1 : 0
  name          = "${local.gke_name}-subnet"
  network       = google_compute_network.this[0].id
  region        = var.gcp_region
  ip_cidr_range = "10.2.0.0/16"
  secondary_ip_range {
    range_name    = "${local.gke_name}-pods"
    ip_cidr_range = "10.3.0.0/16"
  }
  secondary_ip_range {
    range_name    = "${local.gke_name}-services"
    ip_cidr_range = "10.4.0.0/20"
  }
}

resource "google_compute_router" "this" {
  count   = var.enable_gcp ? 1 : 0
  name    = "${local.gke_name}-router"
  network = google_compute_network.this[0].id
  region  = var.gcp_region
}

resource "google_compute_router_nat" "this" {
  count                              = var.enable_gcp ? 1 : 0
  name                               = "${local.gke_name}-nat"
  router                             = google_compute_router.this[0].name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ── GKE Cluster ──────────────────────────────────────────────────────────
resource "google_container_cluster" "this" {
  count                    = var.enable_gcp ? 1 : 0
  name                     = local.gke_name
  location                 = var.gcp_region
  node_locations           = local.gke_zones
  remove_default_node_pool = true
  initial_node_count       = 1
  min_master_version       = var.cluster_version

  network    = google_compute_network.this[0].name
  subnetwork = google_compute_subnetwork.this[0].name

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "${local.gke_name}-pods"
    services_secondary_range_name = "${local.gke_name}-services"
  }

  private_cluster_config {
    enable_private_nodes    = var.private_cluster
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.5.0.0/28"
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_ip_ranges
      content {
        cidr_block   = cidr_blocks.value
        display_name = "authorized-${cidr_blocks.key}"
      }
    }
  }

  workload_identity_config {
    workload_pool = "${data.google_project.current[0].project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  release_channel {
    channel = "REGULAR"
  }

  maintenance_policy {
    maintenance_exclusion {
      exclusion_name = "no-maintenance"
      start_time     = "2026-01-01T00:00:00Z"
      end_time       = "2026-12-31T23:59:59Z"
    }
    recurring_window {
      start_time = "2026-01-01T02:00:00Z"
      end_time   = "2026-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  notification_config {
    pubsub {
      enabled = true
      topic   = google_pubsub_topic.gke_notifications[0].id
    }
  }

  database_encryption {
    state    = "DECRYPTED"
    key_name = ""
  }

  cost_management_config {
    enabled = true
  }

  resource_labels = local.gke_labels

  depends_on = [
    google_compute_subnetwork.this,
    google_compute_router_nat.this,
  ]
}

# ── PubSub for GKE notifications ─────────────────────────────────────────
resource "google_pubsub_topic" "gke_notifications" {
  count  = var.enable_gcp ? 1 : 0
  name   = "${local.gke_name}-notifications"
  labels = local.gke_labels
}

# ── Node Pool ────────────────────────────────────────────────────────────
resource "google_container_node_pool" "this" {
  count              = var.enable_gcp ? 1 : 0
  name               = "${local.gke_name}-primary-pool"
  cluster            = google_container_cluster.this[0].name
  location           = var.gcp_region
  node_locations     = local.gke_zones
  initial_node_count = var.node_min_size

  autoscaling {
    min_node_count = var.node_min_size
    max_node_count = var.node_max_size
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_instance_type
    disk_size_gb    = 100
    disk_type       = "pd-standard"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_nodes[0].email

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = merge(local.gke_labels, {
      "securerag.io/node-pool" = "primary"
    })

    tags = ["gke-node", local.gke_name]
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  depends_on = [google_container_cluster.this]
}

# ── Service Account for GKE Nodes ────────────────────────────────────────
resource "google_service_account" "gke_nodes" {
  count        = var.enable_gcp ? 1 : 0
  account_id   = "${replace(local.gke_name, "-", "")}-node-sa"
  display_name = "GKE Node Service Account - ${local.gke_name}"
  description  = "Service account for GKE node pool of ${local.gke_name}"
}

resource "google_project_iam_member" "gke_node_logging" {
  count   = var.enable_gcp ? 1 : 0
  project = data.google_project.current[0].project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes[0].email}"
}

resource "google_project_iam_member" "gke_node_monitoring" {
  count   = var.enable_gcp ? 1 : 0
  project = data.google_project.current[0].project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes[0].email}"
}

resource "google_project_iam_member" "gke_node_metadataviewer" {
  count   = var.enable_gcp ? 1 : 0
  project = data.google_project.current[0].project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes[0].email}"
}
