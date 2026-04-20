#!/usr/bin/env bash

set -euo pipefail

KYVERNO_ADDON_PATH="${KYVERNO_ADDON_PATH:-infra/k8s/addons/kyverno}"
KYVERNO_POLICY_MODE="${KYVERNO_POLICY_MODE:-audit}"
KYVERNO_AUDIT_POLICY_PATH="${KYVERNO_AUDIT_POLICY_PATH:-infra/k8s/policies/kyverno}"
KYVERNO_ENFORCE_POLICY_PATH="${KYVERNO_ENFORCE_POLICY_PATH:-infra/k8s/policies/kyverno-enforce}"
APPLY_POLICIES="${APPLY_POLICIES:-true}"
KYVERNO_WAIT_TIMEOUT="${KYVERNO_WAIT_TIMEOUT:-300s}"
KYVERNO_WEBHOOK_WARMUP_SECONDS="${KYVERNO_WEBHOOK_WARMUP_SECONDS:-30}"
KYVERNO_POLICY_APPLY_ATTEMPTS="${KYVERNO_POLICY_APPLY_ATTEMPTS:-6}"
KYVERNO_POLICY_APPLY_SLEEP_SECONDS="${KYVERNO_POLICY_APPLY_SLEEP_SECONDS:-20}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

require_command kubectl

apply_policies_with_retry() {
  local policy_path="$1"
  local attempt

  for attempt in $(seq 1 "${KYVERNO_POLICY_APPLY_ATTEMPTS}"); do
    info "Server-side dry-run for Kyverno policies from ${policy_path} (${attempt}/${KYVERNO_POLICY_APPLY_ATTEMPTS})"
    if kubectl apply --server-side --dry-run=server -k "${policy_path}" >/dev/null; then
      info "Applying Kyverno policies from ${policy_path}"
      if kubectl apply --server-side --force-conflicts -k "${policy_path}"; then
        return 0
      fi
    fi

    warn "Kyverno policy admission webhook is not ready yet; retrying in ${KYVERNO_POLICY_APPLY_SLEEP_SECONDS}s"
    kubectl get endpoints -n kyverno kyverno-svc || true
    kubectl get pods -n kyverno -o wide || true
    sleep "${KYVERNO_POLICY_APPLY_SLEEP_SECONDS}"
  done

  error "Unable to apply Kyverno policies after ${KYVERNO_POLICY_APPLY_ATTEMPTS} attempts"
  return 1
}

info "Installing Kyverno from ${KYVERNO_ADDON_PATH}"
kubectl apply --server-side --force-conflicts -k "${KYVERNO_ADDON_PATH}"

info "Waiting for Kyverno deployments to become available"
kubectl wait --for=condition=Available deployment --all -n kyverno --timeout="${KYVERNO_WAIT_TIMEOUT}"

info "Waiting ${KYVERNO_WEBHOOK_WARMUP_SECONDS}s for Kyverno admission webhook endpoints to warm up"
sleep "${KYVERNO_WEBHOOK_WARMUP_SECONDS}"

if ! kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
  error "Kyverno CRDs were not detected after installation"
  exit 1
fi

if is_true "${APPLY_POLICIES}"; then
  policy_path="${KYVERNO_AUDIT_POLICY_PATH}"
  if [[ "${KYVERNO_POLICY_MODE}" == "enforce" ]]; then
    policy_path="${KYVERNO_ENFORCE_POLICY_PATH}"
    warn "Kyverno Enforce mode is mutating admission behavior. Use only after Audit reports are clean and signed image evidence is current."
  fi

  info "Rendering Kyverno policies from ${policy_path}"
  kubectl kustomize "${policy_path}" >/dev/null

  apply_policies_with_retry "${policy_path}"
fi

info "Kyverno installation completed"
kubectl get pods -n kyverno
kubectl get clusterpolicy
kubectl get policyreport,clusterpolicyreport -A || warn "Kyverno policy reports are not available yet; rerun make cluster-security-proof after workloads are reconciled."
