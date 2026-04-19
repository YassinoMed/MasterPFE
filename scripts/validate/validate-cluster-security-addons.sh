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

if ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  {
    printf '# Cluster Security Addons Validation\n\n'
    printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Namespace: `%s`\n\n' "${NS}"
    printf '| Component | Status | Evidence |\n'
    printf '|---|---:|---|\n'
    printf '| Kubernetes API | DÉPENDANT_DE_L_ENVIRONNEMENT | API server unreachable from this environment |\n'
    printf '| metrics-server | DÉPENDANT_DE_L_ENVIRONNEMENT | Cannot validate without a reachable cluster |\n'
    printf '| HPA | DÉPENDANT_DE_L_ENVIRONNEMENT | Cannot validate without a reachable cluster |\n'
    printf '| Kyverno | DÉPENDANT_DE_L_ENVIRONNEMENT | Cannot validate without a reachable cluster |\n\n'
    printf '## Diagnostic\n\n'
    printf '```text\n'
    printf 'kubectl is installed, but the Kubernetes API is not reachable.\n'
    printf 'Context: %s\n' "$(kubectl config current-context 2>/dev/null || printf 'unavailable')"
    printf 'Action: start kind or export a valid kubeconfig, then rerun make cluster-security-proof.\n'
    printf '```\n'
  } > "${OUT_FILE}"

  warn "Kubernetes API is not reachable. Partial addon report written to ${OUT_FILE}"
  exit 0
fi

{
  printf '# Cluster Security Addons Validation\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n\n' "${NS}"
  printf '| Component | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1 \
  && kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=20s >/dev/null 2>&1 \
  && kubectl top nodes >/dev/null 2>&1 \
  && kubectl top pods -n "${NS}" >/dev/null 2>&1; then
  metrics_status="TERMINÉ"
  metrics_detail="Metrics APIService is Available and kubectl top works for nodes and namespace pods"
elif kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  metrics_status="PARTIEL"
  metrics_detail="Metrics APIService exists, but resource metrics are not fully queryable yet"
else
  metrics_status="DÉPENDANT_DE_L_ENVIRONNEMENT"
  metrics_detail="Metrics APIService not detected"
fi
printf '| metrics-server | %s | %s |\n' "${metrics_status}" "${metrics_detail}" >> "${OUT_FILE}"

if hpa_rows="$(kubectl get hpa -n "${NS}" --no-headers 2>/dev/null || true)" && [[ -n "${hpa_rows}" ]]; then
  if grep -q '<unknown>' <<<"${hpa_rows}"; then
    hpa_status="PARTIEL"
    hpa_detail="HPA objects are present, but at least one target is still <unknown>"
  elif [[ "${metrics_status}" == "TERMINÉ" ]]; then
    hpa_status="TERMINÉ"
    hpa_detail="HPA objects are present and targets are populated"
  else
    hpa_status="PARTIEL"
    hpa_detail="HPA objects are present, but metrics-server is not fully proven"
  fi
else
  hpa_status="PARTIEL"
  hpa_detail="No HPA objects returned for namespace"
fi
printf '| HPA | %s | %s |\n' "${hpa_status}" "${hpa_detail}" >> "${OUT_FILE}"

if kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
  if kubectl wait --for=condition=Ready pod --all -n kyverno --timeout=10s >/dev/null 2>&1; then
    kyverno_status="TERMINÉ"
    kyverno_detail="Kyverno CRD detected and controller pods are Ready"
  else
    kyverno_status="PARTIEL"
    kyverno_detail="Kyverno CRD detected but controller pods are not Ready"
  fi
else
  kyverno_status="DÉPENDANT_DE_L_ENVIRONNEMENT"
  kyverno_detail="Kyverno CRD not detected"
fi
printf '| Kyverno | %s | %s |\n' "${kyverno_status}" "${kyverno_detail}" >> "${OUT_FILE}"

if policy_rows="$(kubectl get clusterpolicy --no-headers 2>/dev/null || true)" && [[ -n "${policy_rows}" ]]; then
  policy_status="TERMINÉ"
  policy_detail="ClusterPolicy resources are present"
else
  policy_status="PARTIEL"
  policy_detail="ClusterPolicy resources unavailable or not applied yet"
fi
printf '| Kyverno policies | %s | %s |\n' "${policy_status}" "${policy_detail}" >> "${OUT_FILE}"

if report_rows="$(kubectl get policyreport,clusterpolicyreport -A --no-headers 2>/dev/null || true)" && [[ -n "${report_rows}" ]]; then
  report_status="TERMINÉ"
  report_detail="PolicyReport or ClusterPolicyReport resources are present"
else
  report_status="PARTIEL"
  report_detail="No Kyverno policy reports returned yet"
fi
printf '| Kyverno reports | %s | %s |\n' "${report_status}" "${report_detail}" >> "${OUT_FILE}"

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

if [[ "${metrics_status}" != "TERMINÉ" || "${kyverno_status}" != "TERMINÉ" ]]; then
  warn "Some addons are still environment-dependent. Inspect ${OUT_FILE}"
fi
