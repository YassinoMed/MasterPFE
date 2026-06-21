# Terraform module — Kind cluster
# Provisionne un cluster kind avec la configuration SecureRAG Hub.

resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true
  node_image     = var.node_image

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      api_server_address = var.api_address
      api_server_port    = var.api_port
    }

    dynamic "node" {
      for_each = var.nodes
      content {
        role = node.value.role
        labels = merge(
          node.value.labels,
          node.value.role == "control-plane" ? { "securerag.io/node-pool" = "control-plane" } : { "securerag.io/node-pool" = "app" }
        )
        dynamic "extra_port_mappings" {
          for_each = node.value.role == "control-plane" ? var.port_mappings : []
          content {
            container_port = extra_port_mappings.value.container_port
            host_port      = extra_port_mappings.value.host_port
          }
        }
      }
    }

    dynamic "containerd_config_patches" {
      for_each = var.registry_mirror != "" ? [1] : []
      content {
        content = <<-TOML
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${var.registry_port}"]
          endpoint = ["http://${var.registry_mirror}:5000"]
        TOML
      }
    }
  }
}

variable "cluster_name" {
  type    = string
  default = "securerag-cluster"
}

variable "node_image" {
  type    = string
  default = "kindest/node:v1.33.1"
}

variable "api_address" {
  type    = string
  default = "127.0.0.1"
}

variable "api_port" {
  type    = number
  default = 6443
}

variable "nodes" {
  type = list(object({
    role   = string
    labels = map(string)
  }))
  default = [
    { role = "control-plane", labels = {} },
    { role = "worker", labels = { "topology.kubernetes.io/zone" = "local-a" } },
    { role = "worker", labels = { "topology.kubernetes.io/zone" = "local-b" } },
    { role = "worker", labels = { "topology.kubernetes.io/zone" = "local-c" } },
  ]
}

variable "port_mappings" {
  type = list(object({
    container_port = number
    host_port      = number
  }))
  default = [
    { container_port = 30080, host_port = 8080 },
    { container_port = 30081, host_port = 8081 },
  ]
}

variable "registry_port" {
  type    = number
  default = 5001
}

variable "registry_mirror" {
  type    = string
  default = "kind-registry"
}

output "cluster_endpoint" {
  value = kind_cluster.this.endpoint
}
