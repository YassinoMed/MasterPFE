#!/usr/bin/env bash

set -euo pipefail

METRICS_SERVER_ADDON_PATH="${METRICS_SERVER_ADDON_PATH:-infra/k8s/addons/metrics-server}"
METRICS_SERVER_WAIT_TIMEOUT="${METRICS_SERVER_WAIT_TIMEOUT:-300s}"
VALIDATE_HPA_NAMESPACE="${VALIDATE_HPA_NAMESPACE:-securerag-hub}"

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

if kubectl top nodes >/dev/null 2>&1; then
  info "kubectl top nodes is available"
  kubectl top nodes
else
  warn "kubectl top nodes is not ready yet"
fi

if kubectl top pods -n "${VALIDATE_HPA_NAMESPACE}" >/dev/null 2>&1; then
  info "kubectl top pods is available in ${VALIDATE_HPA_NAMESPACE}"
  kubectl top pods -n "${VALIDATE_HPA_NAMESPACE}"
else
  warn "kubectl top pods is not ready yet in ${VALIDATE_HPA_NAMESPACE}"
fi

info "Current HPA status in ${VALIDATE_HPA_NAMESPACE}"
kubectl get hpa -n "${VALIDATE_HPA_NAMESPACE}"
