#!/usr/bin/env bash

set -euo pipefail

# Collect a factual runtime proof for metrics-server, HPA and Kyverno.
# The script is read-only: it does not install or mutate cluster resources.

NS="${NS:-securerag-hub}"
OUT_DIR="${OUT_DIR:-artifacts/validation}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/cluster-security-addons.md}"

mkdir -p "${OUT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

capture() {
  local title="$1"
  shift

  {
    printf '\n## %s\n\n' "${title}"
    printf '```text\n'
    "$@" 2>&1 || true
    printf '```\n'
  } >> "${OUT_FILE}"
}

require_command kubectl

{
  printf '# Cluster Security Addons Validation\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n\n' "${NS}"
  printf '| Component | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  metrics_status="OK"
  metrics_detail="Metrics APIService exists"
else
  metrics_status="PARTIAL"
  metrics_detail="Metrics APIService not detected"
fi
printf '| metrics-server | %s | %s |\n' "${metrics_status}" "${metrics_detail}" >> "${OUT_FILE}"

if kubectl get hpa -n "${NS}" >/dev/null 2>&1; then
  hpa_status="OK"
  hpa_detail="HPA objects are present"
else
  hpa_status="PARTIAL"
  hpa_detail="No HPA objects returned for namespace"
fi
printf '| HPA | %s | %s |\n' "${hpa_status}" "${hpa_detail}" >> "${OUT_FILE}"

if kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
  kyverno_status="OK"
  kyverno_detail="Kyverno CRD detected"
else
  kyverno_status="PARTIAL"
  kyverno_detail="Kyverno CRD not detected"
fi
printf '| Kyverno | %s | %s |\n' "${kyverno_status}" "${kyverno_detail}" >> "${OUT_FILE}"

if kubectl get clusterpolicy >/dev/null 2>&1; then
  policy_status="OK"
  policy_detail="ClusterPolicy resources can be listed"
else
  policy_status="PARTIAL"
  policy_detail="ClusterPolicy resources unavailable or Kyverno not installed"
fi
printf '| Kyverno policies | %s | %s |\n' "${policy_status}" "${policy_detail}" >> "${OUT_FILE}"

capture "Kubernetes context" kubectl config current-context
capture "Metrics APIService" kubectl get apiservice v1beta1.metrics.k8s.io -o wide
capture "Metrics server pods" kubectl get pods -n kube-system -l k8s-app=metrics-server -o wide
capture "Node metrics" kubectl top nodes
capture "SecureRAG pod metrics" kubectl top pods -n "${NS}"
capture "HPA status" kubectl get hpa -n "${NS}" -o wide
capture "Kyverno pods" kubectl get pods -n kyverno -o wide
capture "Kyverno policies" kubectl get clusterpolicy -o wide
capture "Kyverno policy reports" kubectl get policyreport,clusterpolicyreport -A

info "Cluster security addon validation written to ${OUT_FILE}"

if [[ "${metrics_status}" != "OK" || "${kyverno_status}" != "OK" ]]; then
  warn "Some addons are still environment-dependent. Inspect ${OUT_FILE}"
fi
