# SecureRAG Hub — Terraform Variables
# Variables globales et multi-cloud

# ── Kind (local) ─────────────────────────────────────────────────────────
variable "cluster_name" {
  type        = string
  default     = "securerag-cluster"
  description = "Nom du cluster principal (Kind)"
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

# ── Multi-Cloud Feature Flags ────────────────────────────────────────────
variable "enable_aws" {
  type        = bool
  default     = false
  description = "Activer le provisionnement du cluster AWS EKS"
}

variable "enable_azure" {
  type        = bool
  default     = false
  description = "Activer le provisionnement du cluster Azure AKS"
}

variable "enable_gcp" {
  type        = bool
  default     = false
  description = "Activer le provisionnement du cluster GCP GKE"
}

# ── AWS ──────────────────────────────────────────────────────────────────
variable "aws_region" {
  type        = string
  default     = "eu-west-3"
  description = "Région AWS pour le cluster EKS"
}

# ── Azure ────────────────────────────────────────────────────────────────
variable "azure_location" {
  type        = string
  default     = "westeurope"
  description = "Localisation Azure pour le cluster AKS"
}

# ── GCP ──────────────────────────────────────────────────────────────────
variable "gcp_region" {
  type        = string
  default     = "europe-west1"
  description = "Région GCP pour le cluster GKE"
}

variable "gcp_project_id" {
  type        = string
  default     = ""
  description = "ID du projet GCP (optionnel, utilise le provider par défaut si vide)"
}

# ── Cluster commun ───────────────────────────────────────────────────────
variable "cluster_version" {
  type        = string
  default     = "1.31"
  description = "Version de Kubernetes pour les clusters cloud"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.large"
  description = "Type d'instance pour les nœuds (AWS: instance type, Azure: VM size, GCP: machine type)"
}

variable "node_min_size" {
  type        = number
  default     = 2
  description = "Nombre minimum de nœuds dans le node pool"
}

variable "node_max_size" {
  type        = number
  default     = 6
  description = "Nombre maximum de nœuds dans le node pool"
}

# ── Réseau et sécurité ───────────────────────────────────────────────────
variable "private_cluster" {
  type        = bool
  default     = false
  description = "Activer le cluster privé (sans endpoints publics)"
}

variable "authorized_ip_ranges" {
  type        = list(string)
  default     = []
  description = "Plages IP autorisées pour l'accès au plan de contrôle"
}

# ── Tags / Labels ────────────────────────────────────────────────────────
variable "environment" {
  type        = string
  default     = "production"
  description = "Environnement de déploiement (production, staging, dev)"
}

variable "cost_center" {
  type        = string
  default     = "securerag-hub"
  description = "Centre de coût pour le tagging des ressources cloud"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for VPC"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Default compute instance type"
}

