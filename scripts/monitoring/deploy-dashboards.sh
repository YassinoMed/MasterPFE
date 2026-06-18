#!/usr/bin/env bash
# File: scripts/monitoring/deploy-dashboards.sh
# Description: Deploy all Grafana dashboard ConfigMaps to the cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DASHBOARDS_DIR="${DASHBOARDS_DIR:-${PROJECT_ROOT}/infra/k8s/monitoring/dashboards}"
NAMESPACE="${NAMESPACE:-securerag-monitoring}"
KUSTOMIZE_DIR="${KUSTOMIZE_DIR:-${PROJECT_ROOT}/infra/k8s/monitoring/dashboards}"
DRY_RUN="${DRY_RUN:-false}"

log()   { printf '[INFO]  %s\n' "$*"; }
warn()  { printf '[WARN]  %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    error "kubectl is not installed"
    exit 1
  fi
}

require_kustomize() {
  if ! command -v kustomize &>/dev/null; then
    log "kustomize not found, using kubectl kustomize"
  fi
}

deploy_with_kustomize() {
  log "Deploying dashboards via kustomize from ${KUSTOMIZE_DIR}"

  if [ ! -d "${KUSTOMIZE_DIR}" ]; then
    error "Kustomize directory not found: ${KUSTOMIZE_DIR}"
    exit 1
  fi

  if [ "${DRY_RUN}" = "true" ]; then
    log "DRY RUN: would apply kustomize from ${KUSTOMIZE_DIR}"
    if command -v kustomize &>/dev/null; then
      kustomize build "${KUSTOMIZE_DIR}"
    else
      kubectl kustomize "${KUSTOMIZE_DIR}"
    fi
  else
    if command -v kustomize &>/dev/null; then
      kustomize build "${KUSTOMIZE_DIR}" | kubectl apply -f -
    else
      kubectl kustomize "${KUSTOMIZE_DIR}" | kubectl apply -f -
    fi
    log "Dashboards deployed successfully to namespace ${NAMESPACE}"
  fi
}

deploy_individually() {
  log "Deploying dashboards individually from ${DASHBOARDS_DIR}"

  if [ ! -d "${DASHBOARDS_DIR}" ]; then
    error "Dashboards directory not found: ${DASHBOARDS_DIR}"
    exit 1
  fi

  for file in "${DASHBOARDS_DIR}"/*.json; do
    [ -f "${file}" ] || continue
    dashboard_name=$(basename "${file}" .json)
    log "Processing ${dashboard_name} ..."

    if [ "${DRY_RUN}" = "true" ]; then
      log "  DRY RUN: would apply ${file}"
    else
      kubectl apply -f "${file}" -n "${NAMESPACE}"
    fi
  done
}

deploy_all() {
  if [ -f "${KUSTOMIZE_DIR}/kustomization.yaml" ]; then
    deploy_with_kustomize
  else
    deploy_individually
  fi

  log "Verifying dashboards..."
  kubectl get configmap -n "${NAMESPACE}" -l grafana_dashboard=1 -o name 2>/dev/null || \
    warn "No dashboard ConfigMaps found with label grafana_dashboard=1"

  local count
  count=$(kubectl get configmap -n "${NAMESPACE}" -l grafana_dashboard=1 -o name 2>/dev/null | wc -l)
  log "${count} dashboard ConfigMaps running in namespace ${NAMESPACE}"
}

require_kubectl

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN="true"; shift ;;
    --namespace)   NAMESPACE="$2"; shift 2 ;;
    --dashboards-dir) DASHBOARDS_DIR="$2"; shift 2 ;;
    --kustomize-dir)  KUSTOMIZE_DIR="$2"; shift 2 ;;
    --help|-h)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy Grafana dashboard ConfigMaps to the cluster.

Options:
  --dry-run              Print resources without applying
  --namespace NAMESPACE  Target namespace (default: securerag-monitoring)
  --dashboards-dir DIR   Directory with dashboard ConfigMap files
  --kustomize-dir DIR    Directory with kustomization.yaml
  --help, -h             Show this help message
EOF
      exit 0 ;;
    *) error "Unknown arg: $1"; exit 1 ;;
  esac
done

deploy_all
exit 0
