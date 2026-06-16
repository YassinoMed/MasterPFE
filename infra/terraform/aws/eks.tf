# Terraform AWS EKS — SecureRAG Hub Multi-Cloud
# Feature flag: ENABLE_AWS_EKS=true
# NE REMPLACE PAS le cluster Kind existant — ajoute un cluster supplémentaire.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    helm = { source = "hashicorp/helm", version = "~> 2.15" }
  }
}

variable "cluster_name" { default = "securerag-eks" }
variable "region" { default = "eu-west-3" }
variable "node_count" { default = 3 }
variable "enable_aws" { default = false }

resource "aws_eks_cluster" "securerag" {
  count = var.enable_aws ? 1 : 0
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = "1.33"
  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }
}

resource "aws_eks_node_group" "securerag" {
  count = var.enable_aws ? 1 : 0
  cluster_name    = aws_eks_cluster.securerag[0].name
  node_group_name = "${var.cluster_name}-workers"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = aws_subnet.public[*].id
  scaling_config {
    desired_size = var.node_count
    max_size     = var.node_count + 2
    min_size     = 1
  }
}

# ── Rollback ──
# terraform destroy -target=aws_eks_node_group.securerag
# terraform destroy -target=aws_eks_cluster.securerag
# Le cluster Kind existant n'est pas affecté.
