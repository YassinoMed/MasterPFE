#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
CONFIRM_CLEANUP="${CONFIRM_CLEANUP:-NO}"
DELETE_STATEFUL_LEGACY="${DELETE_STATEFUL_LEGACY:-false}"

legacy_workloads=(
  api-gateway
  knowledge-hub
  llm-orchestrator
  ollama
  qdrant
  security-auditor
)

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    error "Missing required command: kubectl"
    exit 2
  fi
}

legacy_regex() {
  local joined=""
  local name
  for name in "${legacy_workloads[@]}"; do
    if [[ -z "${joined}" ]]; then
      joined="${name}"
    else
      joined="${joined}|${name}"
    fi
  done
  printf '(%s)' "${joined}"
}

runtime_inventory() {
  kubectl get deploy,sts,rs,pod,svc,hpa,pdb,networkpolicy,serviceaccount,pvc -n "${NS}" 2>/dev/null \
    | grep -E "$(legacy_regex)" || true
}

delete_if_present() {
  local kind="$1"
  local name="$2"
  kubectl delete "${kind}" "${name}" -n "${NS}" --ignore-not-found=true
}

delete_by_label() {
  local kind="$1"
  local label="$2"
  kubectl delete "${kind}" -n "${NS}" -l "${label}" --ignore-not-found=true
}

require_kubectl

if ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  warn "Kubernetes API is unreachable. Status: DÉPENDANT_DE_L_ENVIRONNEMENT."
  exit 0
fi

if ! kubectl get namespace "${NS}" >/dev/null 2>&1; then
  warn "Namespace ${NS} does not exist. Nothing to clean."
  exit 0
fi

if [[ "${CONFIRM_CLEANUP}" != "YES" ]]; then
  info "Dry-run only. No object will be deleted."
  info "Legacy runtime objects currently visible in namespace ${NS}:"
  runtime_inventory || true
  cat <<EOF

[INFO] To delete non-stateful legacy runtime objects, run:
       CONFIRM_CLEANUP=YES bash scripts/deploy/cleanup-nonproduction-workloads.sh

[INFO] PVC deletion is intentionally excluded by default.
       To also delete legacy PVCs, add DELETE_STATEFUL_LEGACY=true.
EOF
  exit 0
fi

warn "Mutative cleanup enabled for namespace ${NS}."
warn "This deletes legacy Deployments/StatefulSets/Services/HPA/PDB/NetworkPolicies/ServiceAccounts and orphan pods/replicasets."

for name in "${legacy_workloads[@]}"; do
  info "Cleaning legacy workload ${name}"
  delete_if_present deployment "${name}"
  delete_if_present statefulset "${name}"
  delete_if_present service "${name}"
  delete_if_present hpa "${name}"
  delete_if_present pdb "${name}-pdb"
  delete_if_present networkpolicy "${name}-policy"
  delete_if_present serviceaccount "sa-${name}"
  delete_by_label replicaset "app.kubernetes.io/name=${name}"
  delete_by_label pod "app.kubernetes.io/name=${name}"
done

if [[ "${DELETE_STATEFUL_LEGACY}" == "true" ]]; then
  warn "Deleting legacy PVCs. This is destructive for local stored data."
  delete_if_present pvc ollama-models
  delete_if_present pvc qdrant-storage
else
  info "Legacy PVCs are retained. Set DELETE_STATEFUL_LEGACY=true only when deleting local data is intentional."
fi

info "Remaining legacy runtime objects:"
runtime_inventory || true
