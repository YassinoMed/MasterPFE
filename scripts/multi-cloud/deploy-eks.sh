#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy-eks.sh — Deploy AWS EKS Cluster via Terraform
#
# Usage:
#   export AWS_ACCESS_KEY_ID=...
#   export AWS_SECRET_ACCESS_KEY=...
#   bash scripts/multi-cloud/deploy-eks.sh [apply|destroy|plan]
#
# Actions:
#   apply  (default)  : Provisionne le cluster EKS
#   destroy           : Détruit le cluster EKS
#   plan              : Affiche le plan Terraform
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"

ACTION="${1:-apply}"
shift 2>/dev/null || true

# ── Pre-flight checks ──────────────────────────────────────────────────────
command -v terraform >/dev/null 2>&1 || { echo "[ERROR] terraform is required"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "[ERROR] aws CLI is required"; exit 1; }

if [[ -z "${AWS_ACCESS_KEY_ID:-}" && -z "${AWS_PROFILE:-}" ]]; then
  echo "[ERROR] AWS credentials not found. Set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE."
  exit 1
fi

# ── Variables ──────────────────────────────────────────────────────────────
export TF_VAR_enable_aws="${TF_VAR_enable_aws:-true}"
export TF_VAR_enable_azure="${TF_VAR_enable_azure:-false}"
export TF_VAR_enable_gcp="${TF_VAR_enable_gcp:-false}"
export TF_VAR_aws_region="${TF_VAR_aws_region:-eu-west-3}"
export TF_VAR_cluster_name="${TF_VAR_cluster_name:-securerag}"
export TF_VAR_cluster_version="${TF_VAR_cluster_version:-1.31}"
export TF_VAR_node_instance_type="${TF_VAR_node_instance_type:-t3.large}"
export TF_VAR_node_min_size="${TF_VAR_node_min_size:-2}"
export TF_VAR_node_max_size="${TF_VAR_node_max_size:-6}"
export TF_VAR_environment="${TF_VAR_environment:-production}"
export TF_VAR_cost_center="${TF_VAR_cost_center:-securerag-hub}"

# ── Terraform init ─────────────────────────────────────────────────────────
echo "[INFO] Initializing Terraform in ${TF_DIR}"
terraform -chdir="${TF_DIR}" init -upgrade \
  -backend=true \
  -backend-config="bucket=securerag-terraform-state" \
  -backend-config="key=multi-cloud/eks.tfstate" \
  -backend-config="region=${TF_VAR_aws_region}" \
  -backend-config="dynamodb_table=securerag-terraform-locks" \
  -backend-config="encrypt=true"

# ── Execute action ─────────────────────────────────────────────────────────
case "${ACTION}" in
  apply)
    echo "[INFO] Applying Terraform for AWS EKS..."
    terraform -chdir="${TF_DIR}" apply -auto-approve \
      -target=module.aws
    echo "[INFO] EKS cluster provisioning complete."
    echo "[INFO] Configure kubeconfig:"
    echo "  aws eks update-kubeconfig --region ${TF_VAR_aws_region} --name ${TF_VAR_cluster_name}-eks"
    ;;
  destroy)
    echo "[WARN] Destroying AWS EKS cluster..."
    terraform -chdir="${TF_DIR}" destroy -auto-approve \
      -target=module.aws
    echo "[INFO] EKS cluster destroyed."
    ;;
  plan)
    echo "[INFO] Planning Terraform for AWS EKS..."
    terraform -chdir="${TF_DIR}" plan \
      -target=module.aws
    ;;
  *)
    echo "[ERROR] Unknown action: ${ACTION}. Use apply|destroy|plan."
    exit 1
    ;;
esac
