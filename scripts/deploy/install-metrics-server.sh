#!/usr/bin/env bash

set -euo pipefail

METRICS_SERVER_ADDON_PATH="${METRICS_SERVER_ADDON_PATH:-infra/k8s/addons/metrics-server}"
METRICS_SERVER_WAIT_TIMEOUT="${METRICS_SERVER_WAIT_TIMEOUT:-300s}"
METRICS_READY_TIMEOUT_SECONDS="${METRICS_READY_TIMEOUT_SECONDS:-180}"
VALIDATE_HPA_NAMESPACE="${VALIDATE_HPA_NAMESPACE:-securerag-hub}"
REQUIRE_METRICS_READY="${REQUIRE_METRICS_READY:-true}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

require_command kubectl

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  error "Kubernetes API is unreachable. Start kind or export a valid kubeconfig before installing metrics-server."
  exit 1
fi

info "Rendering metrics-server addon from ${METRICS_SERVER_ADDON_PATH}"
kubectl kustomize "${METRICS_SERVER_ADDON_PATH}" >/dev/null

info "Server-side dry-run for metrics-server addon"
kubectl apply --server-side --dry-run=server -k "${METRICS_SERVER_ADDON_PATH}" >/dev/null

info "Installing metrics-server from ${METRICS_SERVER_ADDON_PATH}"
kubectl apply --server-side --force-conflicts -k "${METRICS_SERVER_ADDON_PATH}"

info "Waiting for metrics-server deployment"
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout="${METRICS_SERVER_WAIT_TIMEOUT}"

info "Checking Metrics API availability"
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout="${METRICS_SERVER_WAIT_TIMEOUT}"

deadline=$((SECONDS + METRICS_READY_TIMEOUT_SECONDS))
top_nodes_ready=false
top_pods_ready=false

while (( SECONDS < deadline )); do
  if kubectl top nodes >/dev/null 2>&1; then
    top_nodes_ready=true
  fi
  if kubectl top pods -n "${VALIDATE_HPA_NAMESPACE}" >/dev/null 2>&1; then
    top_pods_ready=true
  fi
  if [[ "${top_nodes_ready}" == "true" && "${top_pods_ready}" == "true" ]]; then
    break
  fi
  sleep 5
done

if [[ "${top_nodes_ready}" == "true" ]]; then
  info "kubectl top nodes is available"
  kubectl top nodes
else
  warn "kubectl top nodes is not ready after ${METRICS_READY_TIMEOUT_SECONDS}s"
fi

if [[ "${top_pods_ready}" == "true" ]]; then
  info "kubectl top pods is available in ${VALIDATE_HPA_NAMESPACE}"
  kubectl top pods -n "${VALIDATE_HPA_NAMESPACE}"
else
  warn "kubectl top pods is not ready after ${METRICS_READY_TIMEOUT_SECONDS}s in ${VALIDATE_HPA_NAMESPACE}"
fi

info "Current HPA status in ${VALIDATE_HPA_NAMESPACE}"
kubectl get hpa -n "${VALIDATE_HPA_NAMESPACE}"

if hpa_rows="$(kubectl get hpa -n "${VALIDATE_HPA_NAMESPACE}" --no-headers 2>/dev/null || true)" && [[ -n "${hpa_rows}" ]]; then
  if grep -q '<unknown>' <<<"${hpa_rows}"; then
    warn "At least one HPA still reports <unknown>. Metrics are not fully ready for autoscaling evidence."
    [[ "${REQUIRE_METRICS_READY}" == "true" ]] && exit 1
  fi
fi

if [[ "${REQUIRE_METRICS_READY}" == "true" && ( "${top_nodes_ready}" != "true" || "${top_pods_ready}" != "true" ) ]]; then
  error "metrics-server installation completed, but kubectl top evidence is not usable yet."
  exit 1
fi

info "metrics-server installation and runtime metric checks completed"
