# Terraform — Remote State Configuration
# Utilise un backend S3 avec verrouillage DynamoDB pour le locking.
# Décommentez et configurez pour l'environnement cible.

terraform {
  # Pour un stockage distant (AWS S3 / MinIO), décommentez le bloc backend ci-dessous :
  # backend "s3" {
  #   bucket         = "securerag-terraform-state"
  #   key            = "multi-cloud/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "securerag-terraform-locks"
  # }
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
