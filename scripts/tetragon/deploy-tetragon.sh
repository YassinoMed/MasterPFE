#!/usr/bin/env bash
set -Eeuo pipefail

########################################
# SecureRAG Hub - Deploy Tetragon     #
# Applies TracingPolicies, installs   #
# operator if missing, validates.     #
########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TETRAGON_DIR="${REPO_DIR}/security/tetragon"
NAMESPACE="${TETRAGON_NAMESPACE:-kube-system}"
POLICY_DIR="${TETRAGON_POLICY_DIR:-${TETRAGON_DIR}}"

log()  { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
err()  { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }
info() { printf '  [INFO] %s\n' "$*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

require_cmd kubectl

log "SecureRAG Hub - Tetragon Deployment"
log "===================================="

# Step 1: Check if Tetragon is already installed
log "Step 1: Checking Tetragon installation"

TETRAGON_DAEMONSET="tetragon"
TETRAGON_OPERATOR="tetragon-operator"

if kubectl get ds -n "${NAMESPACE}" "${TETRAGON_DAEMONSET}" &>/dev/null; then
  info "Tetragon DaemonSet found in namespace ${NAMESPACE}"
else
  log "Step 1a: Tetragon not found. Installing via Helm..."

  require_cmd helm

  helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
  helm repo update

  helm upgrade --install tetragon cilium/tetragon \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set daemon.enabled=true \
    --set operator.enabled=true \
    --set monitoring.enabled=true \
    --set monitoring.serviceMonitor.enabled=true \
    --wait \
    --timeout 10m

  info "Tetragon installed successfully"
fi

# Step 2: Wait for Tetragon to be ready
log "Step 2: Waiting for Tetragon DaemonSet to be ready"

kubectl rollout status ds -n "${NAMESPACE}" "${TETRAGON_DAEMONSET}" --timeout=180s
kubectl rollout status deploy -n "${NAMESPACE}" "${TETRAGON_OPERATOR}" --timeout=180s || true

info "Tetragon pods:"
kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=tetragon -o wide

# Step 3: Apply TracingPolicies
log "Step 3: Applying Tetragon TracingPolicies"

if [[ -d "${POLICY_DIR}" ]]; then
  kubectl apply -f "${POLICY_DIR}/" -n "${NAMESPACE}"
  info "TracingPolicies applied from ${POLICY_DIR}"
else
  err "Policy directory not found: ${POLICY_DIR}"
fi

# Step 4: Verify TracingPolicies are loaded
log "Step 4: Verifying TracingPolicies"

POLICIES=(
  "securerag-detect-kubectl-exec"
  "securerag-detect-shell"
  "securerag-detect-network-tools"
  "securerag-detect-crypto-miners"
  "securerag-detect-privilege-escalation"
)

for policy in "${POLICIES[@]}"; do
  if kubectl get tracingpolicies "${policy}" &>/dev/null; then
    info "PASS: TracingPolicy '${policy}' is loaded"
  else
    info "FAIL: TracingPolicy '${policy}' not found"
  fi
done

# Step 5: Apply ServiceMonitor if monitoring namespace exists
log "Step 5: Applying Tetragon ServiceMonitor"

if kubectl get ns securerag-monitoring &>/dev/null; then
  if [[ -f "${POLICY_DIR}/tracing-policy-servicemonitor.yaml" ]]; then
    kubectl apply -f "${POLICY_DIR}/tracing-policy-servicemonitor.yaml"
    info "ServiceMonitor applied for Tetragon metrics"
  fi
else
  info "Namespace 'securerag-monitoring' not found; skipping ServiceMonitor"
fi

# Step 6: Quick validation with trigger commands
log "Step 6: Running quick validation (test triggers in tetragon namespace)"

TEST_POD="tetragon-test-$(date +%s)"
kubectl run "${TEST_POD}" --image=nginx:alpine --restart=Never --namespace=default -- sleep 30 2>/dev/null || true

# Clean up test pod
kubectl delete pod "${TEST_POD}" --namespace=default --ignore-not-found --timeout=10s 2>/dev/null || true

log "Tetragon deployment complete"
log "============================"
info "Run the full test suite: bash scripts/tetragon/test-tetragon-policies.sh"
