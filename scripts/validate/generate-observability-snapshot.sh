#!/usr/bin/env bash

set -euo pipefail

# Generate a lightweight observability snapshot without installing tools.
# It is intentionally read-only and works even when the cluster is unavailable,
# producing a factual report instead of failing the soutenance flow.

NS="${NS:-securerag-hub}"
OUT_DIR="${OUT_DIR:-artifacts/observability}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/observability-snapshot.md}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8085}"

mkdir -p "${OUT_DIR}"

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

{
  printf '# Observability Snapshot - SecureRAG Hub\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Jenkins URL: `%s`\n\n' "${JENKINS_URL}"
  printf '## Scope\n\n'
  printf 'This report captures runtime observability evidence without mutating the cluster. It complements, but does not replace, a full Prometheus/Grafana/Loki stack.\n'
} > "${OUT_FILE}"

if command -v kubectl >/dev/null 2>&1 && kubectl version --request-timeout=3s >/dev/null 2>&1; then
  capture "Kubernetes context" kubectl config current-context
  capture "Workloads" kubectl get deploy,sts,pods,svc -n "${NS}" -o wide
  capture "HPA" kubectl get hpa -n "${NS}" -o wide
  capture "PDB" kubectl get pdb -n "${NS}" -o wide
  capture "Recent namespace events" kubectl get events -n "${NS}" --sort-by=.lastTimestamp
  capture "Metrics API" kubectl get apiservice v1beta1.metrics.k8s.io -o wide
  capture "Node metrics" kubectl top nodes
  capture "Pod metrics" kubectl top pods -n "${NS}"
  capture "Kyverno policies" kubectl get clusterpolicy -o wide
  capture "Policy reports" kubectl get policyreport,clusterpolicyreport -A
elif command -v kubectl >/dev/null 2>&1; then
  {
    printf '\n## Kubernetes runtime\n\n'
    printf '```text\n'
    printf 'kubectl is installed, but the Kubernetes API is not reachable from this environment.\n'
    printf 'Context: %s\n' "$(kubectl config current-context 2>/dev/null || printf 'unavailable')"
    printf 'Diagnostic: start kind or export a valid kubeconfig, then rerun make observability-snapshot.\n'
    printf '```\n'
  } >> "${OUT_FILE}"
else
  {
    printf '\n## Kubernetes\n\n'
    printf '```text\nkubectl unavailable in this environment\n```\n'
  } >> "${OUT_FILE}"
fi

if command -v curl >/dev/null 2>&1; then
  capture "Jenkins login endpoint" curl -k -I "${JENKINS_URL%/}/login"
else
  {
    printf '\n## Jenkins\n\n'
    printf '```text\ncurl unavailable in this environment\n```\n'
  } >> "${OUT_FILE}"
fi

cat >> "${OUT_FILE}" <<'EOF'

## Reading guide

- If `kubectl top` fails, metrics-server is not ready or not installed.
- If HPA targets are `<unknown>`, metrics-server is not feeding resource metrics.
- If Kyverno policy reports are absent, Kyverno is not installed or policies have not generated reports yet.
- For the official demo, this snapshot is enough for a factual runtime proof. Prometheus/Grafana/Loki remain an optional expert extension.
EOF

printf 'Observability snapshot written to %s\n' "${OUT_FILE}"
