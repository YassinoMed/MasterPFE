# SecureRAG Hub — Terraform Outputs
# Consolidated outputs for all clouds and local Kind cluster.

# ── Local Kind ───────────────────────────────────────────────────────────
output "cluster_endpoint" {
  value = var.enable_aws ? aws_eks_cluster.this[0].endpoint : (
    var.enable_azure ? azurerm_kubernetes_cluster.this[0].kube_config[0].host : (
      var.enable_gcp ? google_container_cluster.this[0].endpoint : (
        kind_cluster.secure_rag.endpoint
      )
    )
  )
  description = "Endpoint du plan de contrôle Kubernetes"
}

output "argocd_admin_password" {
  value     = var.enable_aws || var.enable_azure || var.enable_gcp ? "Voir les secrets du cluster cloud" : "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive = true
  description = "Mot de passe admin ArgoCD"
}

output "registry_url" {
  value = "localhost:${var.registry_port}"
  description = "URL du registry Docker local"
}

output "bootstrap_complete" {
  value = "Cluster ${var.cluster_name} is ready. ArgoCD auto-sync in progress."
  description = "Message de fin de bootstrap"
}

# ── AWS EKS ──────────────────────────────────────────────────────────────
output "aws_cluster_endpoint" {
  value     = var.enable_aws ? aws_eks_cluster.this[0].endpoint : null
  description = "Endpoint du cluster EKS"
}

output "aws_cluster_ca" {
  value     = var.enable_aws ? aws_eks_cluster.this[0].certificate_authority[0].data : null
  sensitive = true
  description = "CA du cluster EKS (base64)"
}

output "aws_cluster_name" {
  value     = var.enable_aws ? aws_eks_cluster.this[0].name : null
  description = "Nom du cluster EKS"
}

output "aws_oidc_arn" {
  value     = var.enable_aws ? aws_iam_openid_connect_provider.this[0].arn : null
  description = "ARN du provider OIDC EKS pour IRSA"
}

output "aws_vpc_id" {
  value     = var.enable_aws ? aws_vpc.this[0].id : null
  description = "ID du VPC EKS"
}

output "aws_node_group_name" {
  value     = var.enable_aws ? aws_eks_node_group.this[0].node_group_name : null
  description = "Nom du node group managé EKS"
}

# ── Azure AKS ────────────────────────────────────────────────────────────
output "azure_cluster_endpoint" {
  value     = var.enable_azure ? azurerm_kubernetes_cluster.this[0].kube_config[0].host : null
  description = "Endpoint du cluster AKS"
}

output "azure_cluster_ca" {
  value     = var.enable_azure ? base64decode(azurerm_kubernetes_cluster.this[0].kube_config[0].cluster_ca_certificate) : null
  sensitive = true
  description = "CA du cluster AKS (décodé)"
}

output "azure_cluster_name" {
  value     = var.enable_azure ? azurerm_kubernetes_cluster.this[0].name : null
  description = "Nom du cluster AKS"
}

output "azure_oidc_issuer_url" {
  value     = var.enable_azure ? azurerm_kubernetes_cluster.this[0].oidc_issuer_url : null
  description = "URL de l'issuer OIDC AKS pour workload identity"
}

output "azure_resource_group" {
  value     = var.enable_azure ? azurerm_resource_group.this[0].name : null
  description = "Nom du resource group AKS"
}

# ── GCP GKE ──────────────────────────────────────────────────────────────
output "gke_cluster_endpoint" {
  value     = var.enable_gcp ? google_container_cluster.this[0].endpoint : null
  description = "Endpoint du cluster GKE"
}

output "gke_cluster_ca" {
  value     = var.enable_gcp ? google_container_cluster.this[0].master_auth[0].cluster_ca_certificate : null
  sensitive = true
  description = "CA du cluster GKE (base64)"
}

output "gke_cluster_name" {
  value     = var.enable_gcp ? google_container_cluster.this[0].name : null
  description = "Nom du cluster GKE"
}

output "gke_workload_identity_pool" {
  value     = var.enable_gcp ? google_container_cluster.this[0].workload_identity_config[0].workload_pool : null
  description = "Workload Identity pool GKE"
}

output "gke_node_pool_name" {
  value     = var.enable_gcp ? google_container_node_pool.this[0].name : null
  description = "Nom du node pool GKE"
}

# ── Résumé ───────────────────────────────────────────────────────────────
output "multi_cloud_summary" {
  value = <<-EOF
  SecureRAG Hub — Terraform Summary
  ─────────────────────────────────
  AWS EKS enabled:  ${var.enable_aws}
  Azure AKS enabled: ${var.enable_azure}
  GCP GKE enabled:  ${var.enable_gcp}
  Kubernetes version: ${var.cluster_version}

  Access commands:
  ${var.enable_aws   ? "  AWS:  aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}-eks" : ""}
  ${var.enable_azure ? "  Azure: az aks get-credentials --resource-group ${var.cluster_name}-aks-rg --name ${var.cluster_name}-aks" : ""}
  ${var.enable_gcp   ? "  GCP:  gcloud container clusters get-credentials ${var.cluster_name}-gke --region ${var.gcp_region}" : ""}
  EOF
  description = "Résumé multi-cloud"
}
