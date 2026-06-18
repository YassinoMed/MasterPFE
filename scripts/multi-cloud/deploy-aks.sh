#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy-aks.sh — Deploy Azure AKS Cluster via Terraform
#
# Usage:
#   az login
#   bash scripts/multi-cloud/deploy-aks.sh [apply|destroy|plan]
#
# Actions:
#   apply  (default)  : Provisionne le cluster AKS
#   destroy           : Détruit le cluster AKS
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
command -v az >/dev/null 2>&1 || { echo "[ERROR] Azure CLI is required"; exit 1; }

if ! az account show >/dev/null 2>&1; then
  echo "[ERROR] Not logged into Azure. Run 'az login' first."
  exit 1
fi

# ── Variables ──────────────────────────────────────────────────────────────
export TF_VAR_enable_aws="${TF_VAR_enable_aws:-false}"
export TF_VAR_enable_azure="${TF_VAR_enable_azure:-true}"
export TF_VAR_enable_gcp="${TF_VAR_enable_gcp:-false}"
export TF_VAR_azure_location="${TF_VAR_azure_location:-westeurope}"
export TF_VAR_cluster_name="${TF_VAR_cluster_name:-securerag}"
export TF_VAR_cluster_version="${TF_VAR_cluster_version:-1.31}"
export TF_VAR_node_instance_type="${TF_VAR_node_instance_type:-Standard_D2s_v3}"
export TF_VAR_node_min_size="${TF_VAR_node_min_size:-2}"
export TF_VAR_node_max_size="${TF_VAR_node_max_size:-5}"
export TF_VAR_environment="${TF_VAR_environment:-production}"
export TF_VAR_cost_center="${TF_VAR_cost_center:-securerag-hub}"

# ── Terraform init ─────────────────────────────────────────────────────────
echo "[INFO] Initializing Terraform in ${TF_DIR}"
az_account=$(az account show --query "id" -o tsv)
terraform -chdir="${TF_DIR}" init -upgrade \
  -backend=true \
  -backend-config="storage_account_name=secureragterraformstate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=multi-cloud/aks.tfstate" \
  -backend-config="access_key="

# ── Execute action ─────────────────────────────────────────────────────────
case "${ACTION}" in
  apply)
    echo "[INFO] Applying Terraform for Azure AKS..."
    terraform -chdir="${TF_DIR}" apply -auto-approve \
      -target=module.azure
    echo "[INFO] AKS cluster provisioning complete."
    echo "[INFO] Configure kubeconfig:"
    echo "  az aks get-credentials --resource-group ${TF_VAR_cluster_name}-aks-rg --name ${TF_VAR_cluster_name}-aks"
    ;;
  destroy)
    echo "[WARN] Destroying Azure AKS cluster..."
    terraform -chdir="${TF_DIR}" destroy -auto-approve \
      -target=module.azure
    echo "[INFO] AKS cluster destroyed."
    ;;
  plan)
    echo "[INFO] Planning Terraform for Azure AKS..."
    terraform -chdir="${TF_DIR}" plan \
      -target=module.azure
    ;;
  *)
    echo "[ERROR] Unknown action: ${ACTION}. Use apply|destroy|plan."
    exit 1
    ;;
esac
