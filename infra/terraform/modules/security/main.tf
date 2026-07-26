resource "aws_security_group" "loadbalancer" {
  #checkov:skip=CKV2_AWS_5: "Security Group attached to resources in compute module"
  #checkov:skip=CKV_AWS_260: "Public Load Balancer requires HTTP port 80 for web traffic"
  #checkov:skip=CKV_AWS_382: "Outbound egress required for OS updates"
  name        = "securerag-${var.environment}-lb-sg"
  description = "Security group for external Load Balancers"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow Kubernetes API access"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Kubernetes API access alternate"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "securerag-${var.environment}-lb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "control_plane" {
  #checkov:skip=CKV2_AWS_5: "Security Group attached to EC2 instances in compute module"
  #checkov:skip=CKV_AWS_382: "Outbound egress required for OS updates"
  name        = "securerag-${var.environment}-control-plane-sg"
  description = "Security group for control plane instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description     = "Allow Kubernetes API from LB"
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.loadbalancer.id]
  }

  ingress {
    description     = "Allow Kubernetes API alternate from LB"
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.loadbalancer.id]
  }

  ingress {
    description = "Allow full inter-node communication for cluster control plane"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "Allow Cilium VXLAN from workers"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow Cilium Health check from workers"
    from_port   = 4240
    to_port     = 4240
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow Keepalived VRRP unicast"
    from_port   = 0
    to_port     = 0
    protocol    = "112" # Protocol number 112 is VRRP
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "securerag-${var.environment}-control-plane-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "worker" {
  #checkov:skip=CKV2_AWS_5: "Security Group attached to EC2 instances in compute module"
  #checkov:skip=CKV_AWS_382: "Outbound egress required for OS updates"
  name        = "securerag-${var.environment}-worker-sg"
  description = "Security group for worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow inter-node worker communications"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "Allow Kubernetes traffic from control plane"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.control_plane.id]
  }

  ingress {
    description = "Allow Kubernetes NodePorts"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "securerag-${var.environment}-worker-sg"
    Environment = var.environment
  }
}
