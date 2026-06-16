#!/usr/bin/env bash
# bootstrap-gitops.sh — SecureRAG Hub
# Bootstrap complet GitOps : installe ArgoCD + toutes les Applications
# en une seule commande. Aucune intervention humaine requise après exécution.
#
# Usage :
#   bash scripts/gitops/bootstrap-gitops.sh
#
# Prérequis : kubectl configuré sur le cluster cible.

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.14.0}"
REPO_URL="${REPO_URL:-https://github.com/YassinoMed/MasterPFE.git}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

log()  { echo "[$(date -u +%H:%M:%S)] $*"; }
fail() { echo "[FATAL] $*" >&2; exit 1; }

# ── 1. Vérification kubectl ───────────────────────────────────────────
command -v kubectl >/dev/null 2>&1 || fail "kubectl is required"
kubectl cluster-info >/dev/null 2>&1 || fail "Cannot connect to cluster"

log "Cluster connected: $(kubectl config current-context)"

# ── 2. Installer ArgoCD ───────────────────────────────────────────────
if kubectl get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  log "ArgoCD namespace ${ARGOCD_NAMESPACE} already exists."
else
  log "Installing ArgoCD ${ARGOCD_VERSION}..."
  kubectl create namespace "${ARGOCD_NAMESPACE}" || true
  kubectl apply -n "${ARGOCD_NAMESPACE}" \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

  log "Waiting for ArgoCD pods..."
  kubectl wait --for=condition=Ready pods --all -n "${ARGOCD_NAMESPACE}" --timeout=300s || \
    fail "ArgoCD pods did not become ready"

  log "ArgoCD installed."
fi

# ── 3. Appliquer le projet ArgoCD ─────────────────────────────────────
log "Applying ArgoCD AppProject..."
kubectl apply -f "${REPO_ROOT}/infra/k8s/argocd/project.yaml"

# ── 4. Appliquer toutes les Applications ArgoCD ────────────────────────
log "Applying ArgoCD Applications..."
kubectl apply -f "${REPO_ROOT}/infra/k8s/argocd/application-demo.yaml"
kubectl apply -f "${REPO_ROOT}/infra/k8s/argocd/application-production.yaml"
kubectl apply -f "${REPO_ROOT}/infra/k8s/argocd/applicationset-platform.yaml"

# ── 5. Attendre la synchronisation ─────────────────────────────────────
log "Waiting for ArgoCD applications to sync (timeout=600s)..."

apps=(
  securerag-demo
  securerag-production
  securerag-observability
  securerag-backup
  securerag-runtime-detection
  securerag-kyverno
  securerag-kyverno-policies
  securerag-metrics-server
  securerag-secrets
)

for app in "${apps[@]}"; do
  log "  Waiting for ${app}..."
  timeout=600
  elapsed=0
  while [[ ${elapsed} -lt ${timeout} ]]; do
    status=$(kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" \
      -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
    health=$(kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" \
      -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

    if [[ "${status}" == "Synced" && "${health}" == "Healthy" ]]; then
      log "    ${app}: Synced & Healthy"
      break
    elif [[ "${status}" == "NotFound" ]]; then
      log "    ${app}: Not found (may be optional)"
      break
    fi

    sleep 10
    elapsed=$((elapsed + 10))
  done

  if [[ ${elapsed} -ge ${timeout} ]]; then
    log "  [WARN] ${app}: Timeout waiting for sync. Status: ${status:-unknown}, Health: ${health:-unknown}"
  fi
done

# ── 6. Afficher le statut final ────────────────────────────────────────
log ""
log "══════════════════════════════════════════════════════════"
log "  GitOps Bootstrap Complete"
log "══════════════════════════════════════════════════════════"
log ""

kubectl get applications -n "${ARGOCD_NAMESPACE}" -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status,\
REPO:.spec.source.repoURL 2>/dev/null || true

log ""
log "Pods status:"
kubectl get pods -A --field-selector=status.phase!=Running 2>/dev/null | head -20 || true

log ""
log "All components deployed via GitOps."
log "ArgoCD UI: kubectl port-forward -n argocd svc/argocd-server 8080:443"
log "Admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
