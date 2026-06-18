#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy-gke.sh — Deploy GCP GKE Cluster via Terraform
#
# Usage:
#   gcloud auth application-default login
#   bash scripts/multi-cloud/deploy-gke.sh [apply|destroy|plan]
#
# Actions:
#   apply  (default)  : Provisionne le cluster GKE
#   destroy           : Détruit le cluster GKE
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
command -v gcloud >/dev/null 2>&1 || { echo "[ERROR] gcloud CLI is required"; exit 1; }

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "[ERROR] GCP application-default credentials not found."
  echo "  Run: gcloud auth application-default login"
  exit 1
fi

PROJECT_ID="${TF_VAR_gcp_project_id:-$(gcloud config get-value project 2>/dev/null || true)}"
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
  echo "[ERROR] GCP project not set. Set TF_VAR_gcp_project_id or run: gcloud config set project <PROJECT_ID>"
  exit 1
fi

# ── Variables ──────────────────────────────────────────────────────────────
export TF_VAR_enable_aws="${TF_VAR_enable_aws:-false}"
export TF_VAR_enable_azure="${TF_VAR_enable_azure:-false}"
export TF_VAR_enable_gcp="${TF_VAR_enable_gcp:-true}"
export TF_VAR_gcp_region="${TF_VAR_gcp_region:-europe-west1}"
export TF_VAR_gcp_project_id="${PROJECT_ID}"
export TF_VAR_cluster_name="${TF_VAR_cluster_name:-securerag}"
export TF_VAR_cluster_version="${TF_VAR_cluster_version:-1.31}"
export TF_VAR_node_instance_type="${TF_VAR_node_instance_type:-e2-standard-2}"
export TF_VAR_node_min_size="${TF_VAR_node_min_size:-2}"
export TF_VAR_node_max_size="${TF_VAR_node_max_size:-6}"
export TF_VAR_environment="${TF_VAR_environment:-production}"
export TF_VAR_cost_center="${TF_VAR_cost_center:-securerag-hub}"

# ── Terraform init (GCS backend) ──────────────────────────────────────────
echo "[INFO] Initializing Terraform in ${TF_DIR}"
terraform -chdir="${TF_DIR}" init -upgrade \
  -backend=true \
  -backend-config="bucket=securerag-terraform-state-${PROJECT_ID}" \
  -backend-config="prefix=multi-cloud/gke" \
  -backend-config="project=${PROJECT_ID}"

# ── Execute action ─────────────────────────────────────────────────────────
case "${ACTION}" in
  apply)
    echo "[INFO] Applying Terraform for GCP GKE..."
    terraform -chdir="${TF_DIR}" apply -auto-approve \
      -target=module.gcp
    echo "[INFO] GKE cluster provisioning complete."
    echo "[INFO] Configure kubeconfig:"
    echo "  gcloud container clusters get-credentials ${TF_VAR_cluster_name}-gke --region ${TF_VAR_gcp_region} --project ${PROJECT_ID}"
    ;;
  destroy)
    echo "[WARN] Destroying GCP GKE cluster..."
    terraform -chdir="${TF_DIR}" destroy -auto-approve \
      -target=module.gcp
    echo "[INFO] GKE cluster destroyed."
    ;;
  plan)
    echo "[INFO] Planning Terraform for GCP GKE..."
    terraform -chdir="${TF_DIR}" plan \
      -target=module.gcp
    ;;
  *)
    echo "[ERROR] Unknown action: ${ACTION}. Use apply|destroy|plan."
    exit 1
    ;;
esac
