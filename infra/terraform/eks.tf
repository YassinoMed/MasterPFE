# Terraform AWS EKS — SecureRAG Hub Multi-Cloud
# Feature flag: enable_aws (bool)
# Provisionne un cluster EKS complet avec IRSA, autoscaler, CSI, CoreDNS, VPC CNI.

locals {
  eks_name = "${var.cluster_name}-eks"
  azs      = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "SecureRAG-Hub"
    Cluster     = local.eks_name
    CostCenter  = var.cost_center
  }
}

# ── VPC ──────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_12: "Default security group restricted in root module"
  #checkov:skip=CKV2_AWS_11: "VPC Flow logs enabled in dedicated network module"
  count                = var.enable_aws ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.tags, { Name = "${local.eks_name}-vpc" })
}

resource "aws_subnet" "public" {
  count                   = var.enable_aws ? length(local.azs) : 0
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = cidrsubnet(aws_vpc.this[0].cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${local.eks_name}-public-${local.azs[count.index]}" })
}

resource "aws_subnet" "private" {
  count             = var.enable_aws ? length(local.azs) : 0
  vpc_id            = aws_vpc.this[0].id
  cidr_block        = cidrsubnet(aws_vpc.this[0].cidr_block, 8, count.index + 3)
  availability_zone = local.azs[count.index]
  tags              = merge(local.tags, { Name = "${local.eks_name}-private-${local.azs[count.index]}" })
}

resource "aws_internet_gateway" "this" {
  count  = var.enable_aws ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = merge(local.tags, { Name = "${local.eks_name}-igw" })
}

resource "aws_eip" "nat" {
  count  = var.enable_aws ? 1 : 0
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${local.eks_name}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_aws ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(local.tags, { Name = "${local.eks_name}-nat" })
}

resource "aws_route_table" "public" {
  count  = var.enable_aws ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }
  tags = merge(local.tags, { Name = "${local.eks_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = var.enable_aws ? length(local.azs) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count  = var.enable_aws ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[0].id
  }
  tags = merge(local.tags, { Name = "${local.eks_name}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = var.enable_aws ? length(local.azs) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# ── IAM ──────────────────────────────────────────────────────────────────
resource "aws_iam_role" "eks_cluster" {
  count = var.enable_aws ? 1 : 0
  name  = "${local.eks_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.enable_aws ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  count      = var.enable_aws ? 1 : 0
  role       = aws_iam_role.eks_cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_role" "eks_node" {
  count = var.enable_aws ? 1 : 0
  name  = "${local.eks_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  count      = var.enable_aws ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = var.enable_aws ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly" {
  count      = var.enable_aws ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_ssm_managed" {
  count      = var.enable_aws ? 1 : 0
  role       = aws_iam_role.eks_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── Security Group ───────────────────────────────────────────────────────
resource "aws_security_group" "eks_cluster" {
  count       = var.enable_aws ? 1 : 0
  name        = "${local.eks_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.this[0].id
  tags        = merge(local.tags, { Name = "${local.eks_name}-cluster-sg" })
}

# ── EKS Cluster ──────────────────────────────────────────────────────────
resource "aws_eks_cluster" "this" {
  count    = var.enable_aws ? 1 : 0
  name     = local.eks_name
  role_arn = aws_iam_role.eks_cluster[0].arn
  version  = var.cluster_version
  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = var.private_cluster
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster[0].id]
  }
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  tags                      = local.tags
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
}

# ── OIDC Provider (IRSA) ─────────────────────────────────────────────────
data "tls_certificate" "eks" {
  count = var.enable_aws ? 1 : 0
  url   = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  count           = var.enable_aws ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
  tags            = local.tags
}

# ── Managed Node Group ───────────────────────────────────────────────────
resource "aws_eks_node_group" "this" {
  count           = var.enable_aws ? 1 : 0
  cluster_name    = aws_eks_cluster.this[0].name
  node_group_name = "${local.eks_name}-managed-ng"
  node_role_arn   = aws_iam_role.eks_node[0].arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"
  scaling_config {
    desired_size = var.node_min_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }
  update_config {
    max_unavailable = 1
  }
  labels = {
    "securerag.io/node-pool" = "managed"
  }
  tags = merge(local.tags, {
    "k8s.io/cluster-autoscaler/${local.eks_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"           = "true"
  })
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
  ]
}

# ── EBS CSI Driver Addon ─────────────────────────────────────────────────
resource "aws_iam_role" "ebs_csi" {
  count              = var.enable_aws ? 1 : 0
  name               = "${local.eks_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume[0].json
  tags               = local.tags
}

data "aws_iam_policy_document" "ebs_csi_assume" {
  count = var.enable_aws ? 1 : 0
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this[0].arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this[0].url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_aws ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  count                       = var.enable_aws ? 1 : 0
  cluster_name                = aws_eks_cluster.this[0].name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = "v1.38.0-eksbuild.1"
  service_account_role_arn    = aws_iam_role.ebs_csi[0].arn
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags
}

# ── VPC CNI Addon ────────────────────────────────────────────────────────
resource "aws_eks_addon" "vpc_cni" {
  count                       = var.enable_aws ? 1 : 0
  cluster_name                = aws_eks_cluster.this[0].name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.19.0-eksbuild.1"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags
}

# ── CoreDNS Addon ────────────────────────────────────────────────────────
resource "aws_eks_addon" "coredns" {
  count                       = var.enable_aws ? 1 : 0
  cluster_name                = aws_eks_cluster.this[0].name
  addon_name                  = "coredns"
  addon_version               = "v1.11.4-eksbuild.1"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags
}

# ── Cluster Autoscaler (IRSA) ────────────────────────────────────────────
resource "aws_iam_role" "cluster_autoscaler" {
  count              = var.enable_aws ? 1 : 0
  name               = "${local.eks_name}-cluster-autoscaler-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume[0].json
  tags               = local.tags
}

data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  count = var.enable_aws ? 1 : 0
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this[0].arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this[0].url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }
  }
}

data "aws_iam_policy_document" "cluster_autoscaler_policy" {
  count = var.enable_aws ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count  = var.enable_aws ? 1 : 0
  name   = "${local.eks_name}-cluster-autoscaler-policy"
  policy = data.aws_iam_policy_document.cluster_autoscaler_policy[0].json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count      = var.enable_aws ? 1 : 0
  role       = aws_iam_role.cluster_autoscaler[0].name
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
}

# ── CoreDNS Autoscaler (IRSA) ────────────────────────────────────────────
resource "aws_iam_role" "coredns_autoscaler" {
  count              = var.enable_aws ? 1 : 0
  name               = "${local.eks_name}-coredns-autoscaler-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume[0].json
  tags               = local.tags
}
