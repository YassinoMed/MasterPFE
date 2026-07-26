resource "aws_ebs_volume" "etcd_backup" {
  count             = 3
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  size              = 20
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "securerag-${var.environment}-etcd-backup-vol-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_ebs_volume" "postgres_data" {
  availability_zone = var.availability_zones[0]
  size              = 50
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "securerag-${var.environment}-postgres-vol"
    Environment = var.environment
  }
}

resource "aws_ebs_volume" "qdrant_data" {
  availability_zone = var.availability_zones[1 % length(var.availability_zones)]
  size              = 50
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "securerag-${var.environment}-qdrant-vol"
    Environment = var.environment
  }
}
