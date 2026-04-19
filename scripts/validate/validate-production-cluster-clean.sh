#!/usr/bin/env bash

set -euo pipefail

OVERLAY="${OVERLAY:-infra/k8s/overlays/production}"
NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-cluster-clean.md}"
STATIC_ONLY="${STATIC_ONLY:-false}"

official_workloads=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

legacy_workloads=(
  api-gateway
  knowledge-hub
  llm-orchestrator
  ollama
  qdrant
  security-auditor
)

mkdir -p "${REPORT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

capture() {
  local title="$1"
  shift

  {
    printf '\n## %s\n\n' "${title}"
    printf '```text\n'
    "$@" 2>&1 || true
    printf '```\n'
  } >> "${REPORT_FILE}"
}

row() {
  local component="$1"
  local check="$2"
  local status="$3"
  local evidence="$4"

  printf '| %s | %s | %s | %s |\n' "${component}" "${check}" "${status}" "${evidence}" >> "${REPORT_FILE}"
}

require_command kubectl
require_command ruby

rendered="$(mktemp)"
trap 'rm -f "${rendered}"' EXIT

kubectl kustomize "${OVERLAY}" > "${rendered}"

{
  printf '# Production Cluster Clean Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Overlay: `%s`\n' "${OVERLAY}"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Static-only mode: `%s`\n\n' "${STATIC_ONLY}"
  printf '| Component | Check | Status | Evidence |\n'
  printf '|---|---|---:|---|\n'
} > "${REPORT_FILE}"

set +e
ruby -W0 -ryaml - "${rendered}" "${REPORT_FILE}" <<'RUBY'
rendered, report_file = ARGV
official = %w[portal-web auth-users chatbot-manager conversation-service audit-security-service]
legacy = %w[api-gateway knowledge-hub llm-orchestrator ollama qdrant security-auditor]

docs = YAML.load_stream(File.read(rendered)).compact.select { |doc| doc.is_a?(Hash) }
resources = docs.map { |doc| [doc["kind"], doc.dig("metadata", "name"), doc] }

def append_row(report_file, component, check, status, evidence)
  File.open(report_file, "a") do |f|
    f.puts "| #{component} | #{check} | #{status} | #{evidence} |"
  end
end

failures = []

official.each do |name|
  exists = resources.any? { |kind, resource_name, _doc| kind == "Deployment" && resource_name == name }
  append_row(report_file, "`#{name}`", "official Deployment rendered", exists ? "TERMINÉ" : "FAIL", exists ? "Deployment present" : "Deployment missing")
  failures << "Missing official Deployment #{name}" unless exists
end

legacy.each do |name|
  found = resources.select do |kind, resource_name, _doc|
    %w[Deployment StatefulSet Service HorizontalPodAutoscaler PodDisruptionBudget NetworkPolicy ServiceAccount PersistentVolumeClaim].include?(kind) &&
      resource_name.to_s.match?(/\A(sa-)?#{Regexp.escape(name)}(-pdb|-policy)?\z/)
  end
  ok = found.empty?
  evidence = ok ? "not rendered" : found.map { |kind, resource_name, _| "#{kind}/#{resource_name}" }.join(", ")
  append_row(report_file, "`#{name}`", "excluded from production render", ok ? "TERMINÉ" : "FAIL", evidence)
  failures << "Legacy resource rendered for #{name}" unless ok
end

portal_service = resources.find { |kind, resource_name, _doc| kind == "Service" && resource_name == "portal-web" }&.last
service_type = portal_service&.dig("spec", "type") || "ClusterIP"
node_port = (portal_service&.dig("spec", "ports") || []).find { |port| port["name"] == "http" || port["port"].to_i == 8000 }&.dig("nodePort")
nodeport_ok = service_type == "NodePort" && node_port.to_i == 30081
append_row(report_file, "`portal-web`", "official production exposure", nodeport_ok ? "TERMINÉ" : "FAIL", "type=#{service_type}, nodePort=#{node_port || "none"}")
failures << "portal-web Service is not NodePort 30081" unless nodeport_ok

exit(failures.empty? ? 0 : 1)
RUBY
static_rc=$?
set -e

if [[ "${STATIC_ONLY}" == "true" ]]; then
  if [[ "${static_rc}" -eq 0 ]]; then
    printf '\n## Runtime\n\nStatic-only mode requested. Runtime proof is PRÊT_NON_EXÉCUTÉ.\n' >> "${REPORT_FILE}"
  fi
  exit "${static_rc}"
fi

if ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  row "Kubernetes API" "runtime proof" "DÉPENDANT_DE_L_ENVIRONNEMENT" "API server unreachable"
  printf '\n## Runtime diagnostic\n\nStart a cluster, select the kubeconfig context, deploy `%s`, then rerun this script.\n' "${OVERLAY}" >> "${REPORT_FILE}"
  exit "${static_rc}"
fi

runtime_rc=0
row "Kubernetes API" "runtime proof" "TERMINÉ" "API server reachable"

if ! kubectl get namespace "${NS}" >/dev/null 2>&1; then
  row "Namespace" "${NS}" "DÉPENDANT_DE_L_ENVIRONNEMENT" "namespace missing"
  runtime_rc=1
else
  for name in "${official_workloads[@]}"; do
    if kubectl get deployment "${name}" -n "${NS}" >/dev/null 2>&1; then
      desired="$(kubectl get deployment "${name}" -n "${NS}" -o jsonpath='{.spec.replicas}' 2>/dev/null || printf '0')"
      ready="$(kubectl get deployment "${name}" -n "${NS}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
      ready="${ready:-0}"
      if [[ "${desired}" != "0" && "${ready}" == "${desired}" ]]; then
        row "\`${name}\`" "replicas Ready" "TERMINÉ" "ready=${ready}/${desired}"
      else
        row "\`${name}\`" "replicas Ready" "PARTIEL" "ready=${ready}/${desired}"
        runtime_rc=1
      fi
    else
      row "\`${name}\`" "Deployment exists" "PARTIEL" "missing from namespace ${NS}"
      runtime_rc=1
    fi
  done

  legacy_found="$(kubectl get deploy,sts,svc,hpa,pdb,networkpolicy,serviceaccount -n "${NS}" 2>/dev/null | grep -E '(api-gateway|knowledge-hub|llm-orchestrator|ollama|qdrant|security-auditor)' || true)"
  if [[ -z "${legacy_found}" ]]; then
    row "legacy runtime" "absent from namespace" "TERMINÉ" "no legacy objects detected"
  else
    row "legacy runtime" "absent from namespace" "PARTIEL" "legacy objects still present"
    runtime_rc=1
  fi

  legacy_pvc_found="$(kubectl get pvc -n "${NS}" 2>/dev/null | grep -E '(ollama-models|qdrant-storage)' || true)"
  if [[ -z "${legacy_pvc_found}" ]]; then
    row "legacy PVCs" "absent from namespace" "TERMINÉ" "no legacy PVC detected"
  else
    row "legacy PVCs" "absent from namespace" "PARTIEL" "retained intentionally; delete with DELETE_STATEFUL_LEGACY=true only if data loss is acceptable"
    runtime_rc=1
  fi

  svc_type="$(kubectl get svc portal-web -n "${NS}" -o jsonpath='{.spec.type}' 2>/dev/null || true)"
  svc_nodeport="$(kubectl get svc portal-web -n "${NS}" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null || true)"
  if [[ "${svc_type}" == "NodePort" && "${svc_nodeport}" == "30081" ]]; then
    row "\`portal-web\`" "runtime exposure" "TERMINÉ" "type=NodePort, nodePort=30081"
  else
    row "\`portal-web\`" "runtime exposure" "PARTIEL" "type=${svc_type:-missing}, nodePort=${svc_nodeport:-missing}"
    runtime_rc=1
  fi
fi

not_ready_nodes="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" {print $1 "=" $2}' || true)"
if [[ -z "${not_ready_nodes}" ]]; then
  row "Nodes" "all Ready" "TERMINÉ" "all nodes report Ready"
else
  row "Nodes" "all Ready" "PARTIEL" "${not_ready_nodes}"
  runtime_rc=1
fi

capture "Kubernetes context" kubectl config current-context
capture "Nodes" kubectl get nodes -o wide
capture "Namespace runtime inventory" kubectl get deploy,svc,pdb,hpa -n "${NS}" -o wide
capture "Pods" kubectl get pods -n "${NS}" -o wide
capture "Legacy runtime inventory" kubectl get deploy,sts,svc,hpa,pdb,networkpolicy,serviceaccount,pvc -n "${NS}"

cat >> "${REPORT_FILE}" <<'EOF'

## Reading guide

- `TERMINÉ` means the static or runtime control succeeded.
- `PARTIEL` means the cluster answered but the production-only runtime is not clean or not fully Ready.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means no active Kubernetes API or namespace was available.
- `PRÊT_NON_EXÉCUTÉ` means the validation was intentionally limited to static rendering.
EOF

if [[ "${static_rc}" -ne 0 || "${runtime_rc}" -ne 0 ]]; then
  warn "Production cluster clean validation produced gaps. Report: ${REPORT_FILE}"
  exit 1
fi

info "Production cluster clean validation passed. Report: ${REPORT_FILE}"
