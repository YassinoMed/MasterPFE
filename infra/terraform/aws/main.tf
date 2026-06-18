# Terraform — AWS EKS Cluster (Standalone Configuration)
# Usage: terraform -chdir=infra/terraform/aws init && terraform -chdir=infra/terraform/aws apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket         = "securerag-terraform-state"
    key            = "aws-eks/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "securerag-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = "SecureRAG-Hub"
      CostCenter  = var.cost_center
    }
  }
}

variable "cluster_name" {
  type        = string
  default     = "securerag"
  description = "Nom de base du cluster"
}

variable "aws_region" {
  type        = string
  default     = "eu-west-3"
  description = "Région AWS"
}

variable "cluster_version" {
  type        = string
  default     = "1.31"
  description = "Version Kubernetes"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.large"
  description = "Type d'instance pour les nœuds"
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
