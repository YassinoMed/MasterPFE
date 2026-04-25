#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
OUT_DIR="${OUT_DIR:-artifacts/validation}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/ha-chaos-lite-report.md}"
RUN_POD_DELETE="${RUN_POD_DELETE:-false}"
RUN_ROLLOUT_RESTART="${RUN_ROLLOUT_RESTART:-false}"
RUN_NODE_DRAIN="${RUN_NODE_DRAIN:-false}"
CONFIRM_CHAOS_LITE="${CONFIRM_CHAOS_LITE:-NO}"
CONFIRM_NODE_DRAIN="${CONFIRM_NODE_DRAIN:-NO}"
NODE_NAME="${NODE_NAME:-}"

official_deployments=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

mkdir -p "${OUT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

row() {
  local check="$1"
  local status="$2"
  local evidence="$3"
  printf '| %s | %s | %s |\n' "${check}" "${status}" "${evidence}" >> "${OUT_FILE}"
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

{
  printf '# HA Chaos Lite Report - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- RUN_POD_DELETE: `%s`\n' "${RUN_POD_DELETE}"
  printf -- '- RUN_ROLLOUT_RESTART: `%s`\n' "${RUN_ROLLOUT_RESTART}"
  printf -- '- RUN_NODE_DRAIN: `%s`\n\n' "${RUN_NODE_DRAIN}"
  printf '| Check | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

if ! command -v kubectl >/dev/null 2>&1; then
  row "kubectl" "DÉPENDANT_DE_L_ENVIRONNEMENT" "kubectl unavailable"
  info "HA chaos lite report written to ${OUT_FILE}"
  exit 0
fi

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  row "Kubernetes API" "DÉPENDANT_DE_L_ENVIRONNEMENT" "API server unreachable"
  capture "Kubernetes context" kubectl config current-context
  info "HA chaos lite report written to ${OUT_FILE}"
  exit 0
fi

row "Kubernetes API" "TERMINÉ" "API server reachable"

for deploy in "${official_deployments[@]}"; do
  if kubectl wait --for=condition=Available "deployment/${deploy}" -n "${NS}" --timeout=30s >/dev/null 2>&1; then
    row "deployment/${deploy} available" "TERMINÉ" "Available condition true"
  else
    row "deployment/${deploy} available" "PARTIEL" "Deployment not Available within 30s"
  fi
done

if kubectl get pdb -n "${NS}" -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.status.disruptionsAllowed}{"\n"}{end}' >/tmp/securerag-pdb-allowed.txt 2>/dev/null; then
  if awk -F= 'NF == 2 && $2+0 >= 1 {ok++} END {exit ok > 0 ? 0 : 1}' /tmp/securerag-pdb-allowed.txt; then
    row "PDB allowed disruptions" "TERMINÉ" "at least one PDB allows safe disruption"
  else
    row "PDB allowed disruptions" "PARTIEL" "no PDB currently allows disruption"
  fi
else
  row "PDB allowed disruptions" "PARTIEL" "unable to query PDB status"
fi

if kubectl get pods -n "${NS}" -o wide >/tmp/securerag-pods-wide.txt 2>/dev/null; then
  node_count="$(awk 'NR>1 {nodes[$7]=1} END {print length(nodes)}' /tmp/securerag-pods-wide.txt)"
  if [[ "${node_count:-0}" -ge 2 ]]; then
    row "Pod node spread" "TERMINÉ" "official pods span ${node_count} nodes"
  else
    row "Pod node spread" "PARTIEL" "official pods span ${node_count:-0} node(s)"
  fi
else
  row "Pod node spread" "PARTIEL" "unable to query pods"
fi

if is_true "${RUN_POD_DELETE}" && [[ "${CONFIRM_CHAOS_LITE}" != "YES" ]]; then
  row "Pod delete recovery" "PRÊT_NON_EXÉCUTÉ" "requires CONFIRM_CHAOS_LITE=YES with RUN_POD_DELETE=true"
elif is_true "${RUN_POD_DELETE}"; then
  for deploy in "${official_deployments[@]}"; do
    pod="$(kubectl get pods -n "${NS}" -l "app.kubernetes.io/name=${deploy}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    if [[ -z "${pod}" ]]; then
      row "pod delete ${deploy}" "PARTIEL" "no pod found"
      continue
    fi
    kubectl delete pod "${pod}" -n "${NS}" --wait=false >/dev/null
    if kubectl rollout status "deployment/${deploy}" -n "${NS}" --timeout=120s >/dev/null 2>&1; then
      row "pod delete ${deploy}" "TERMINÉ" "deleted ${pod}; deployment recovered"
    else
      row "pod delete ${deploy}" "PARTIEL" "deleted ${pod}; rollout did not recover within timeout"
    fi
  done
else
  row "Pod delete recovery" "PRÊT_NON_EXÉCUTÉ" "set RUN_POD_DELETE=true to delete one pod per official deployment"
fi

if is_true "${RUN_ROLLOUT_RESTART}" && [[ "${CONFIRM_CHAOS_LITE}" != "YES" ]]; then
  row "Rollout restart proof" "PRÊT_NON_EXÉCUTÉ" "requires CONFIRM_CHAOS_LITE=YES with RUN_ROLLOUT_RESTART=true"
elif is_true "${RUN_ROLLOUT_RESTART}"; then
  for deploy in "${official_deployments[@]}"; do
    kubectl rollout restart "deployment/${deploy}" -n "${NS}" >/dev/null
    if kubectl rollout status "deployment/${deploy}" -n "${NS}" --timeout=180s >/dev/null 2>&1; then
      row "rollout restart ${deploy}" "TERMINÉ" "restart completed"
    else
      row "rollout restart ${deploy}" "PARTIEL" "restart did not complete within timeout"
    fi
  done
else
  row "Rollout restart proof" "PRÊT_NON_EXÉCUTÉ" "set RUN_ROLLOUT_RESTART=true to restart official deployments"
fi

if is_true "${RUN_NODE_DRAIN}"; then
  if [[ "${CONFIRM_CHAOS_LITE}" != "YES" || "${CONFIRM_NODE_DRAIN}" != "YES" || -z "${NODE_NAME}" ]]; then
    row "Node drain proof" "PRÊT_NON_EXÉCUTÉ" "requires CONFIRM_CHAOS_LITE=YES CONFIRM_NODE_DRAIN=YES and NODE_NAME"
  else
    warn "Mutating action: draining node ${NODE_NAME}"
    kubectl drain "${NODE_NAME}" --ignore-daemonsets --delete-emptydir-data --force --timeout=180s >/dev/null
    kubectl uncordon "${NODE_NAME}" >/dev/null
    recovered=true
    for deploy in "${official_deployments[@]}"; do
      if ! kubectl wait --for=condition=Available "deployment/${deploy}" -n "${NS}" --timeout=180s >/dev/null 2>&1; then
        recovered=false
      fi
    done
    if [[ "${recovered}" == "true" ]]; then
      row "Node drain proof" "TERMINÉ" "drained and uncordoned ${NODE_NAME}; deployments available"
    else
      row "Node drain proof" "PARTIEL" "drained ${NODE_NAME}, but deployment availability did not recover cleanly"
    fi
  fi
else
  row "Node drain proof" "PRÊT_NON_EXÉCUTÉ" "set RUN_NODE_DRAIN=true CONFIRM_NODE_DRAIN=YES NODE_NAME=<worker>"
fi

capture "Deployments" kubectl get deploy -n "${NS}" -o wide
capture "Pods" kubectl get pods -n "${NS}" -o wide
capture "PDB" kubectl get pdb -n "${NS}" -o wide
capture "HPA" kubectl get hpa -n "${NS}" -o wide
capture "Recent events" kubectl get events -n "${NS}" --sort-by=.lastTimestamp

cat >> "${OUT_FILE}" <<'EOF'

## Safety model

- Default mode is read-only.
- Pod delete and rollout restart are mutative but bounded to official Laravel deployments and require `CONFIRM_CHAOS_LITE=YES`.
- Node drain is guarded by `CONFIRM_NODE_DRAIN=YES` and explicit `NODE_NAME`.
EOF

info "HA chaos lite report written to ${OUT_FILE}"
