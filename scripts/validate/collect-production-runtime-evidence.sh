#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
OUT_DIR="${OUT_DIR:-artifacts/validation}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/production-runtime-evidence.md}"
TAIL_LINES="${TAIL_LINES:-120}"

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

status_line() {
  local component="$1"
  local status="$2"
  local detail="$3"

  printf '| %s | %s | %s |\n' "${component}" "${status}" "${detail}" >> "${OUT_FILE}"
}

{
  printf '# Production Runtime Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n\n' "${NS}"
  printf '| Component | Status | Detail |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

if ! command -v kubectl >/dev/null 2>&1; then
  status_line "kubectl" "DÉPENDANT_DE_L_ENVIRONNEMENT" "kubectl is not installed"
  printf '\n## Diagnostic\n\nInstall kubectl or run this from the Jenkins/container image that contains kubectl.\n' >> "${OUT_FILE}"
  printf '[WARN] kubectl missing. Report: %s\n' "${OUT_FILE}" >&2
  exit 0
fi

if ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  status_line "Kubernetes API" "DÉPENDANT_DE_L_ENVIRONNEMENT" "API server unreachable"
  capture "Kubernetes context" kubectl config current-context
  printf '\n## Diagnostic\n\nStart kind or export a valid kubeconfig, then rerun this script.\n' >> "${OUT_FILE}"
  printf '[WARN] Kubernetes API unreachable. Report: %s\n' "${OUT_FILE}" >&2
  exit 0
fi

status_line "Kubernetes API" "TERMINÉ" "API server reachable"

deploy_ready="PARTIEL"
if kubectl wait --for=condition=Available deployment/portal-web deployment/auth-users deployment/chatbot-manager deployment/conversation-service deployment/audit-security-service -n "${NS}" --timeout=30s >/dev/null 2>&1; then
  deploy_ready="TERMINÉ"
fi
status_line "Official deployments" "${deploy_ready}" "Availability check for five Laravel workloads"

if kubectl get hpa -n "${NS}" --no-headers >/dev/null 2>&1 && [[ -n "$(kubectl get hpa -n "${NS}" --no-headers 2>/dev/null || true)" ]]; then
  status_line "HPA objects" "TERMINÉ" "HPA resources returned for namespace"
else
  status_line "HPA objects" "PARTIEL" "No HPA resources returned for namespace"
fi

if kubectl top pods -n "${NS}" >/dev/null 2>&1 && kubectl top nodes >/dev/null 2>&1; then
  status_line "metrics-server" "TERMINÉ" "kubectl top works for pods and nodes"
else
  status_line "metrics-server" "DÉPENDANT_DE_L_ENVIRONNEMENT" "kubectl top pods/nodes unavailable"
fi

if kubectl get pdb -n "${NS}" --no-headers >/dev/null 2>&1 && [[ -n "$(kubectl get pdb -n "${NS}" --no-headers 2>/dev/null || true)" ]]; then
  status_line "PodDisruptionBudget" "TERMINÉ" "PDB resources returned for namespace"
else
  status_line "PodDisruptionBudget" "PARTIEL" "No PDB resources returned for namespace"
fi

capture "Kubernetes context" kubectl config current-context
capture "Deployments" kubectl get deploy -n "${NS}" -o wide
capture "Pods" kubectl get pods -n "${NS}" -o wide
capture "Services" kubectl get svc -n "${NS}" -o wide
capture "ServiceAccounts" kubectl get sa -n "${NS}" -o wide
capture "Roles and RoleBindings" kubectl get role,rolebinding -n "${NS}" -o wide
capture "PDB" kubectl get pdb -n "${NS}" -o wide
capture "HPA" kubectl get hpa -n "${NS}" -o wide
capture "ResourceQuota" kubectl get resourcequota -n "${NS}" -o wide
capture "LimitRange" kubectl get limitrange -n "${NS}" -o wide
capture "NetworkPolicies" kubectl get networkpolicy -n "${NS}" -o wide
capture "Pod images and imageIDs" bash -c \
  "kubectl get pods -n '${NS}' -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{range .status.containerStatuses[*]}{.image}{\"\\t\"}{.imageID}{\"\\n\"}{end}{end}'"
capture "Recent events" kubectl get events -n "${NS}" --sort-by=.lastTimestamp
capture "Metrics APIService" kubectl get apiservice v1beta1.metrics.k8s.io -o wide
capture "Node metrics" kubectl top nodes
capture "Pod metrics" kubectl top pods -n "${NS}"

for deployment in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
  capture "Describe deployment/${deployment}" kubectl describe deploy "${deployment}" -n "${NS}"
  capture "Logs deployment/${deployment}" kubectl logs -n "${NS}" "deployment/${deployment}" --tail="${TAIL_LINES}" --all-containers=true
done

cat >> "${OUT_FILE}" <<'EOF'

## Reading guide

- `TERMINÉ` means the runtime command succeeded in the current cluster.
- `PARTIEL` means the Kubernetes object is missing or incomplete.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means an active cluster, metrics-server or kubeconfig is required.
- This script is read-only and does not install, patch, delete or restart any workload.
EOF

printf '[INFO] Production runtime evidence written to %s\n' "${OUT_FILE}"
