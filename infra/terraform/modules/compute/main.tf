data "aws_ami" "ubuntu" {
  count       = 0
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : "ami-0123456789abcdef0"
}

resource "tls_private_key" "deploy_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  key_name   = "securerag-${var.environment}-key"
  public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.deploy_key.public_key_openssh
}

resource "aws_iam_role" "control_plane" {
  name = "securerag-${var.environment}-cp-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "control_plane" {
  name = "securerag-${var.environment}-cp-profile"
  role = aws_iam_role.control_plane.name
}

resource "aws_iam_role" "worker" {
  name = "securerag-${var.environment}-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "worker" {
  name = "securerag-${var.environment}-worker-profile"
  role = aws_iam_role.worker.name
}

resource "aws_instance" "control_plane" {
  count                  = 3
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.control_plane_sg_id]
  key_name               = aws_key_pair.k8s_key.key_name
  ebs_optimized          = true
  monitoring             = true
  iam_instance_profile   = aws_iam_instance_profile.control_plane.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "securerag-${var.environment}-cp0${count.index + 1}"
    Role        = "control-plane"
    Environment = var.environment
  }
}

resource "aws_instance" "worker" {
  count                  = 3
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.worker_sg_id]
  key_name               = aws_key_pair.k8s_key.key_name
  ebs_optimized          = true
  monitoring             = true
  iam_instance_profile   = aws_iam_instance_profile.worker.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "securerag-${var.environment}-worker0${count.index + 1}"
    Role        = "worker"
    Environment = var.environment
  }
}
