# SecureRAG Hub — Terraform Variables

variable "cluster_name" {
  type        = string
  default     = "securerag-cluster"
  description = "Nom du cluster Kubernetes (kind)"
}

variable "registry_port" {
  type        = number
  default     = 5001
  description = "Port du registry Docker local"
}

variable "argocd_helm_version" {
  type        = string
  default     = "7.3.0"
  description = "Version du chart Helm ArgoCD"
}

variable "argocd_apps_repo" {
  type        = string
  default     = "https://github.com/YassinoMed/MasterPFE.git"
  description = "URL du dépôt Git contenant les Applications ArgoCD"
}

variable "argocd_apps_revision" {
  type        = string
  default     = "main"
  description = "Branche Git pour les Applications ArgoCD"
}
