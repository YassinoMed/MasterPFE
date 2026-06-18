#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy-management-cluster.sh — Deploy Management Cluster (Kind) for Cluster API
#
# Provisionne un cluster Kind (management) qui hébergera les providers
# Cluster API pour provisionner des clusters Kubernetes sur AWS, Azure, GCP.
#
# Usage:
#   bash scripts/multi-cloud/deploy-management-cluster.sh [create|destroy|capi-install|kubeconfig]
#
# Actions:
#   create       : Crée le cluster Kind management
#   destroy      : Détruit le cluster Kind management
#   capi-install : Installe les providers Cluster API sur le management cluster
#   kubeconfig   : Exporte le kubeconfig du management cluster
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ACTION="${1:-create}"
shift 2>/dev/null || true

# ── Configuration ──────────────────────────────────────────────────────────
MGMT_CLUSTER_NAME="${MGMT_CLUSTER_NAME:-securerag-mgmt}"
MGMT_NODE_IMAGE="${MGMT_NODE_IMAGE:-kindest/node:v1.33.1}"
MGMT_CONFIG="${MGMT_CONFIG:-${REPO_ROOT}/infra/kind/kind-mgmt.yaml}"
CAPI_VERSION="${CAPI_VERSION:-v1.9.0}"
CAPI_PROVIDERS="${CAPI_PROVIDERS:-aws}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/${MGMT_CLUSTER_NAME}.yaml}"

# ── Logging ────────────────────────────────────────────────────────────────
log()  { printf '[INFO]  %s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
warn() { printf '[WARN]  %s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }
fail() { printf '[ERROR] %s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; exit 1; }

# ── Pre-flight checks ──────────────────────────────────────────────────────
preflight() {
  command -v docker >/dev/null 2>&1 || fail "docker is required"
  command -v kind >/dev/null 2>&1 || fail "kind is required"
  command -v kubectl >/dev/null 2>&1 || fail "kubectl is required"
  command -v clusterctl >/dev/null 2>&1 || warn "clusterctl not found, will download"
  log "Pre-flight checks passed"
}

# ── Create management cluster ──────────────────────────────────────────────
create_cluster() {
  log "Creating management cluster: ${MGMT_CLUSTER_NAME}"

  # Create Kind config if not exists
  if [[ ! -f "${MGMT_CONFIG}" ]]; then
    log "Creating Kind config at ${MGMT_CONFIG}"
    mkdir -p "$(dirname "${MGMT_CONFIG}")"
    cat > "${MGMT_CONFIG}" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${MGMT_CLUSTER_NAME}
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 8080
      - containerPort: 30081
        hostPort: 8081
  - role: worker
  - role: worker
  - role: worker
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
EOF
  fi

  if kind get clusters 2>/dev/null | grep -qx "${MGMT_CLUSTER_NAME}"; then
    log "Management cluster ${MGMT_CLUSTER_NAME} already exists"
  else
    kind create cluster --name "${MGMT_CLUSTER_NAME}" --config "${MGMT_CONFIG}" --image "${MGMT_NODE_IMAGE}"
    log "Management cluster created"
  fi

  # Wait for nodes
  kubectl wait --for=condition=Ready nodes --all --timeout=180s
  log "All nodes ready"
}

# ── Install Cluster API providers ──────────────────────────────────────────
install_capi() {
  log "Installing Cluster API providers"

  # Install clusterctl if missing
  if ! command -v clusterctl >/dev/null 2>&1; then
    log "Downloading clusterctl ${CAPI_VERSION}"
    ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
    curl -fsSL "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CAPI_VERSION}/clusterctl-linux-${ARCH}" \
      -o /usr/local/bin/clusterctl
    chmod +x /usr/local/bin/clusterctl
  fi

  # Set kubeconfig context to management cluster
  export KUBECONFIG="${KUBECONFIG_PATH}"
  kind get kubeconfig --name "${MGMT_CLUSTER_NAME}" > "${KUBECONFIG_PATH}"

  # Initialize Cluster API with selected providers
  log "Initializing Cluster API with providers: ${CAPI_PROVIDERS}"
  clusterctl init \
    --infrastructure "${CAPI_PROVIDERS}" \
    --wait-providers \
    --kubeconfig "${KUBECONFIG_PATH}"

  log "Cluster API providers installed successfully"
}

# ── Export kubeconfig ──────────────────────────────────────────────────────
export_kubeconfig() {
  log "Exporting kubeconfig for management cluster ${MGMT_CLUSTER_NAME}"
  mkdir -p "$(dirname "${KUBECONFIG_PATH}")"
  kind get kubeconfig --name "${MGMT_CLUSTER_NAME}" > "${KUBECONFIG_PATH}"
  log "Kubeconfig written to ${KUBECONFIG_PATH}"
  log "  export KUBECONFIG=${KUBECONFIG_PATH}"
}

# ── Destroy management cluster ─────────────────────────────────────────────
destroy_cluster() {
  log "WARNING: Destroying management cluster ${MGMT_CLUSTER_NAME}"
  read -rp "Continue? (y/N) " confirm
  if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
    log "Aborted"
    exit 0
  fi

  kind delete cluster --name "${MGMT_CLUSTER_NAME}"
  log "Management cluster destroyed"
}

# ── Main ───────────────────────────────────────────────────────────────────
main() {
  log "╔═══════════════════════════════════════════════════════════════╗"
  log "║  SecureRAG Hub — Management Cluster (Kind + CAPI)           ║"
  log "║  Cluster: ${MGMT_CLUSTER_NAME}                               ║"
  log "╚═══════════════════════════════════════════════════════════════╝"

  preflight

  case "${ACTION}" in
    create)
      create_cluster
      export_kubeconfig
      ;;
    capi-install)
      install_capi
      ;;
    kubeconfig)
      export_kubeconfig
      ;;
    destroy)
      destroy_cluster
      ;;
    *)
      echo "Usage: $0 [create|destroy|capi-install|kubeconfig]"
      exit 1
      ;;
  esac

  log "Action '${ACTION}' completed successfully"
}

main "$@"
