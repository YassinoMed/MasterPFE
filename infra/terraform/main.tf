# Terraform — SecureRAG Hub Cluster
# Provisionne le cluster Kubernetes (kind) + registry + ArgoCD + Root App.
# Alternative au script shell cluster-bootstrap.sh.
#
# Usage :
#   cd infra/terraform
#   terraform init
#   terraform apply -auto-approve
#
# Après terraform apply, le cluster est entièrement fonctionnel.

# Terraform et providers configurés dans provider.tf
# Backend configuré dans remote-state.tf

# ── Cluster kind ───────────────────────────────────────────────────────

resource "kind_cluster" "secure_rag" {
  name       = var.cluster_name
  wait_for_ready = true
  node_image = "kindest/node:v1.33.1"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      api_server_address = "127.0.0.1"
      api_server_port    = 6443
    }

    containerd_config_patches = [
      <<-TOML
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${var.registry_port}"]
        endpoint = ["http://kind-registry:5000"]
      TOML
    ]

    node {
      role = "control-plane"
      labels = {
        "securerag.io/node-pool" = "control-plane"
      }
      extra_port_mappings {
        container_port = 30080
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 30081
        host_port      = 8081
      }
    }

    node {
      role = "worker"
      labels = {
        "securerag.io/node-pool" = "app"
        "topology.kubernetes.io/zone" = "local-a"
      }
    }
    node {
      role = "worker"
      labels = {
        "securerag.io/node-pool" = "app"
        "topology.kubernetes.io/zone" = "local-b"
      }
    }
  }
}

# ── Registry Docker ────────────────────────────────────────────────────

resource "docker_image" "registry" {
  name = "registry:2"
}

resource "docker_container" "registry" {
  name  = "kind-registry"
  image = docker_image.registry.image_id
  restart = "always"

  ports {
    internal = 5000
    external = var.registry_port
  }

  networks_advanced {
    name = "kind"
  }
}

# ── Namespace ArgoCD ───────────────────────────────────────────────────

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "app.kubernetes.io/part-of"          = "securerag-hub"
    }
  }
  depends_on = [kind_cluster.secure_rag]
}

# ── ArgoCD via Helm ────────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  version          = var.argocd_helm_version
  wait             = true
  timeout          = 600

  values = [
    <<-YAML
    global:
      domain: argocd.local
    configs:
      params:
        server.insecure: true
    server:
      extraArgs:
        - --insecure
    YAML
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ── Root Application (App of Apps) ─────────────────────────────────────

resource "kubectl_manifest" "root_app" {
  depends_on = [helm_release.argocd]

  yaml_body = <<-YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: securerag-root
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/YassinoMed/MasterPFE.git
    targetRevision: main
    path: infra/k8s/argocd
    directory:
      recurse: false
      include: '*.yaml'
      exclude: 'application-root.yaml|namespace.yaml|README.md'
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - ServerSideApply=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
YAML
}

# Les variables sont maintenant définies dans variables.tf
# Les outputs sont maintenant définis dans outputs.tf (multi-cloud consolidation)
