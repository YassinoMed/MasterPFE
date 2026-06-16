# Terraform — Backend configuration (S3/MinIO)
# Utilise un bucket S3-compatible pour stocker l'état Terraform.
# Pour environnement local/demo : utiliser le backend local par défaut.

terraform {
  backend "s3" {
    # À configurer pour l'environnement cible
    # bucket         = "securerag-terraform-state"
    # key            = "platform/terraform.tfstate"
    # region         = "us-east-1"
    # endpoint       = "http://minio.securerag-hub.svc:9000"
    # access_key     = "minioadmin"
    # secret_key     = "minioadmin"
    # skip_credentials_validation = true
    # skip_metadata_api_check     = true
    # force_path_style            = true
  }
}
