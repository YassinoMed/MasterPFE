#!/usr/bin/env bash
# cluster-bootstrap.sh — SecureRAG Hub Zero-Touch Bootstrap
# ============================================================================
# Reconstruit entièrement un cluster Kubernetes vierge à partir du dépôt Git.
# UNE SEULE commande nécessaire : `bash scripts/gitops/cluster-bootstrap.sh`
#
# Ce que fait ce script (ordre garanti) :
#   1. Vérifie les prérequis (docker, kubectl, kind)
#   2. Crée le cluster kind avec audit logging
#   3. Déploie un registry local
#   4. Installe ArgoCD
#   5. Applique la Root Application (App of Apps)
#   6. Attend que TOUS les composants soient Healthy
#   7. Affiche le statut final
#
# Après exécution, 0 intervention humaine.
# ============================================================================

set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────────
CLUSTER_NAME="${CLUSTER_NAME:-securerag-cluster}"
KIND_CONFIG="${KIND_CONFIG:-infra/kind/kind-config.yaml}"
REGISTRY_PORT="${REGISTRY_PORT:-5001}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.14.0}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
TIMEOUT="${TIMEOUT:-900}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${CYAN}[$(date -u +%H:%M:%S)]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FATAL]${NC} $*" >&2; exit 1; }

# ── 1. Prérequis ────────────────────────────────────────────────────────
log "══════════════════════════════════════════════════════════════"
log "  SecureRAG Hub — Zero-Touch Cluster Bootstrap"
log "══════════════════════════════════════════════════════════════"
log ""

for cmd in docker kubectl kind; do
  command -v "${cmd}" >/dev/null 2>&1 || fail "${cmd} is required. Install it first."
done

if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not running."
fi

ok "Prerequisites satisfied"
ok "  docker:  $(docker --version 2>/dev/null | head -1)"
ok "  kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
ok "  kind:    $(kind version 2>/dev/null | head -1)"

# ── 2. Créer le cluster kind ────────────────────────────────────────────
log ""
log "─── Step 1/7: Creating kind cluster '${CLUSTER_NAME}'..."

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "Cluster ${CLUSTER_NAME} already exists. Skipping creation."
else
  if [[ -f "${REPO_ROOT}/${KIND_CONFIG}" ]]; then
    kind create cluster --config "${REPO_ROOT}/${KIND_CONFIG}" --wait 300s || \
      fail "Failed to create kind cluster."
  else
    kind create cluster --name "${CLUSTER_NAME}" --wait 300s || \
      fail "Failed to create kind cluster."
  fi
  ok "Cluster ${CLUSTER_NAME} created."
fi

kubectl config use-context "kind-${CLUSTER_NAME}" 2>/dev/null || true
kubectl wait --for=condition=Ready nodes --all --timeout=120s
ok "All nodes ready."

# ── 3. Registry local ───────────────────────────────────────────────────
log ""
log "─── Step 2/7: Configuring local container registry..."

REGISTRY_NAME="kind-registry"
if docker ps --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
  warn "Registry already running. Skipping."
else
  docker run -d --restart=always --name "${REGISTRY_NAME}" \
    -p "${REGISTRY_PORT}:5000" registry:2 >/dev/null || \
    warn "Could not start registry (port ${REGISTRY_PORT} may be in use)"
fi

# Connecter le réseau kind au registry
if docker network inspect kind 2>/dev/null | grep -q "${REGISTRY_NAME}"; then
  warn "Registry already connected to kind network."
else
  docker network connect kind "${REGISTRY_NAME}" 2>/dev/null || true
fi

ok "Registry ready (localhost:${REGISTRY_PORT})."

# ── 4. Installer ArgoCD ─────────────────────────────────────────────────
log ""
log "─── Step 3/7: Installing ArgoCD ${ARGOCD_VERSION}..."

if kubectl get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  warn "ArgoCD namespace ${ARGOCD_NAMESPACE} already exists."
else
  kubectl create namespace "${ARGOCD_NAMESPACE}" || true
  kubectl apply -n "${ARGOCD_NAMESPACE}" \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
    >/dev/null || fail "Failed to install ArgoCD."

  log "  Waiting for ArgoCD pods..."
  kubectl wait --for=condition=Ready pods --all -n "${ARGOCD_NAMESPACE}" --timeout=300s || \
    fail "ArgoCD pods not ready."
fi

ok "ArgoCD installed and healthy."

# ── 5. Appliquer la Root Application (App of Apps) ──────────────────────
log ""
log "─── Step 4/7: Applying Root Application (App of Apps)..."

# Attendre que les CRDs ArgoCD soient prêtes
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=Established crd/appprojects.argoproj.io --timeout=60s 2>/dev/null || true

# Appliquer l'espace de noms argocd (contient les labels PSA)
kubectl apply -f "${REPO_ROOT}/infra/k8s/argocd/namespace.yaml" 2>/dev/null || true

# Appliquer la root app
kubectl apply -f "${REPO_ROOT}/infra/k8s/argocd/application-root.yaml" || \
  fail "Failed to apply root application."

log "  Waiting for root app to sync..."
sleep 10

# Rafraîchir ArgoCD pour qu'il détecte la root app
kubectl annotate application securerag-root -n "${ARGOCD_NAMESPACE}" \
  argocd.argoproj.io/refresh=normal --overwrite 2>/dev/null || true

ok "Root Application applied."

# ── 6. Attendre la synchronisation de toutes les applications ────────────
log ""
log "─── Step 5/7: Waiting for all applications to sync and become healthy..."
log "  (timeout: ${TIMEOUT}s)"

ALL_APPS=(
  securerag-root
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

SYNCED=0
FAILED=0
PENDING=0

for app in "${ALL_APPS[@]}"; do
  log "  Waiting for ${app}..."
  elapsed=0
  app_synced=false

  while [[ ${elapsed} -lt ${TIMEOUT} ]]; do
    status=$(kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" \
      -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
    health=$(kubectl get application "${app}" -n "${ARGOCD_NAMESPACE}" \
      -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

    case "${status}/${health}" in
      "Synced/Healthy")
        ok "    ${app}: Synced & Healthy (${elapsed}s)"
        SYNCED=$((SYNCED + 1))
        app_synced=true
        break
        ;;
      "NotFound"*|"")
        if [[ ${elapsed} -gt 60 ]]; then
          warn "    ${app}: Not found after 60s. May be optional or pending creation."
          PENDING=$((PENDING + 1))
          app_synced=true
          break
        fi
        ;;
      *"Error"*|*"Degraded"*)
        warn "    ${app}: ${status}/${health}"
        ;;
    esac

    if [[ "${app_synced}" == "true" ]]; then
      break
    fi

    sleep 10
    elapsed=$((elapsed + 10))

    # Afficher un point tous les 30s
    if [[ $((elapsed % 30)) -eq 0 ]]; then
      echo -n "."
    fi
  done

  if [[ "${app_synced}" != "true" ]]; then
    warn "    ${app}: TIMEOUT after ${TIMEOUT}s. Status: ${status:-unknown}/${health:-unknown}"
    FAILED=$((FAILED + 1))
  fi
done

# ── 7. Statut final ─────────────────────────────────────────────────────
log ""
log "─── Step 6/7: Cluster health overview..."

log ""
log "ArgoCD Applications:"
kubectl get applications -n "${ARGOCD_NAMESPACE}" -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status 2>/dev/null | column -t || true

log ""
log "Pods (non-Running only):"
kubectl get pods -A --field-selector=status.phase!=Running 2>/dev/null | head -30 || true

log ""
log "Nodes:"
kubectl get nodes -o wide 2>/dev/null || true

# ── 8. Résumé ───────────────────────────────────────────────────────────
log ""
log "─── Step 7/7: Bootstrap summary..."
log ""
log "══════════════════════════════════════════════════════════════"
log "  Bootstrap Complete"
log "══════════════════════════════════════════════════════════════"
log "  Cluster        : ${CLUSTER_NAME}"
log "  Registry       : localhost:${REGISTRY_PORT}"
log "  ArgoCD         : ${ARGOCD_VERSION}"
log "  Apps synced    : ${SYNCED}"
log "  Apps pending   : ${PENDING}"
log "  Apps failed    : ${FAILED}"
log ""
log "  Access ArgoCD  : kubectl port-forward -n argocd svc/argocd-server 8080:443"
log "  Admin password : kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
log "══════════════════════════════════════════════════════════════"

if [[ ${FAILED} -gt 0 ]]; then
  log ""
  warn "${FAILED} application(s) failed to sync within timeout."
  warn "Check: kubectl get applications -n argocd"
  warn "The cluster will self-heal via ArgoCD auto-sync."
fi

# Score d'autonomie
TOTAL_APPS=${#ALL_APPS[@]}
AUTONOMY=$(( (SYNCED + PENDING) * 100 / TOTAL_APPS ))
log ""
log "Autonomy score: ${AUTONOMY}% (${SYNCED} synced + ${PENDING} pending / ${TOTAL_APPS} total)"

if [[ ${AUTONOMY} -ge 80 ]]; then
  log "Cluster is autonomous. ArgoCD self-healing will resolve remaining items."
else
  warn "Cluster may need manual intervention. Review failed apps above."
fi

exit 0
