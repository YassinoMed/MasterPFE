# Terraform — Remote State Configuration
# Utilise un backend S3 avec verrouillage DynamoDB pour le locking.
# Décommentez et configurez pour l'environnement cible.

terraform {
  backend "s3" {
    # ── Configuration minimale ──────────────────────────────────────────
    # bucket         = "securerag-terraform-state"
    # key            = "multi-cloud/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "securerag-terraform-locks"
    #
    # ── Pour MinIO local / S3-compatible ────────────────────────────────
    # endpoint                       = "http://minio.securerag-hub.svc:9000"
    # access_key                     = "minioadmin"
    # secret_key                     = "minioadmin"
    # skip_credentials_validation    = true
    # skip_metadata_api_check        = true
    # skip_region_validation         = true
    # skip_requesting_account_id     = true
    # force_path_style               = true
    #
    # ── Pour AWS S3 standard ────────────────────────────────────────────
    # profile = "securerag-production"
    # role_arn = "arn:aws:iam::123456789012:role/TerraformStateAccess"
  }
}

# ── DynamoDB Table for State Locking (à créer séparément) ────────────────
# resource "aws_dynamodb_table" "terraform_lock" {
#   provider     = aws
#   name         = "securerag-terraform-locks"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"
#
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
#
#   tags = {
#     Environment = var.environment
#     ManagedBy   = "terraform"
#     Project     = "SecureRAG-Hub"
#     Name        = "securerag-terraform-locks"
#   }
# }
