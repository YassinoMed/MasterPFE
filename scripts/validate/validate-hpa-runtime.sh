#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
OUT_DIR="${OUT_DIR:-artifacts/validation}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/hpa-runtime-report.md}"
STRICT="${STRICT:-false}"

expected_hpas=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

mkdir -p "${OUT_DIR}"

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
  } >> "${OUT_FILE}"
}

row() {
  local component="$1"
  local check="$2"
  local status="$3"
  local evidence="$4"

  printf '| %s | %s | %s | %s |\n' "${component}" "${check}" "${status}" "${evidence}" >> "${OUT_FILE}"
}

require_command kubectl
require_command ruby

{
  printf '# HPA Runtime Report - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Strict mode: `%s`\n\n' "${STRICT}"
  printf '| Component | Check | Status | Evidence |\n'
  printf '|---|---|---:|---|\n'
} > "${OUT_FILE}"

failures=0

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  row "Kubernetes API" "reachable" "DÉPENDANT_DE_L_ENVIRONNEMENT" "API server unreachable"
  printf '\n## Diagnostic\n\nStart kind or export a valid kubeconfig, deploy `infra/k8s/overlays/production`, install metrics-server, then rerun this script.\n' >> "${OUT_FILE}"
  [[ "${STRICT}" == "true" ]] && exit 1
  info "HPA runtime report written to ${OUT_FILE}"
  exit 0
fi

row "Kubernetes API" "reachable" "TERMINÉ" "API server reachable"

if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  if kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=20s >/dev/null 2>&1; then
    row "metrics-server" "Metrics APIService Available" "TERMINÉ" "v1beta1.metrics.k8s.io Available"
  else
    row "metrics-server" "Metrics APIService Available" "PARTIEL" "APIService exists but is not Available"
    failures=$((failures + 1))
  fi
else
  row "metrics-server" "Metrics APIService exists" "DÉPENDANT_DE_L_ENVIRONNEMENT" "v1beta1.metrics.k8s.io not found"
  failures=$((failures + 1))
fi

if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  ready="$(kubectl get deployment metrics-server -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  desired="$(kubectl get deployment metrics-server -n kube-system -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
  ready="${ready:-0}"
  desired="${desired:-0}"
  if [[ "${desired}" != "0" && "${ready}" == "${desired}" ]]; then
    row "metrics-server" "Deployment Ready" "TERMINÉ" "ready=${ready}/${desired}"
  else
    row "metrics-server" "Deployment Ready" "PARTIEL" "ready=${ready}/${desired}"
    failures=$((failures + 1))
  fi
else
  row "metrics-server" "Deployment exists" "DÉPENDANT_DE_L_ENVIRONNEMENT" "deployment/metrics-server missing in kube-system"
  failures=$((failures + 1))
fi

if kubectl top nodes >/dev/null 2>&1; then
  row "kubectl top" "nodes" "TERMINÉ" "node metrics returned"
else
  row "kubectl top" "nodes" "PARTIEL" "node metrics unavailable"
  failures=$((failures + 1))
fi

if kubectl top pods -n "${NS}" >/dev/null 2>&1; then
  row "kubectl top" "pods" "TERMINÉ" "pod metrics returned for ${NS}"
else
  row "kubectl top" "pods" "PARTIEL" "pod metrics unavailable for ${NS}"
  failures=$((failures + 1))
fi

hpa_json="$(mktemp)"
trap 'rm -f "${hpa_json}"' EXIT
if kubectl get hpa -n "${NS}" -o json > "${hpa_json}" 2>/dev/null; then
  set +e
  ruby -rjson - "${hpa_json}" "${OUT_FILE}" "${expected_hpas[@]}" <<'RUBY'
file, report, *expected = ARGV
data = JSON.parse(File.read(file))
items = data.fetch("items", [])
by_name = items.to_h { |item| [item.dig("metadata", "name"), item] }
failures = 0

def append_row(report, component, check, status, evidence)
  File.open(report, "a") do |f|
    f.puts "| #{component} | #{check} | #{status} | #{evidence} |"
  end
end

expected.each do |name|
  hpa = by_name[name]
  unless hpa
    append_row(report, "`#{name}`", "HPA exists", "PARTIEL", "missing")
    failures += 1
    next
  end

  append_row(report, "`#{name}`", "HPA exists", "TERMINÉ", "HorizontalPodAutoscaler present")

  current_metrics = hpa.dig("status", "currentMetrics") || []
  spec_metrics = hpa.dig("spec", "metrics") || []
  metric_names = current_metrics.map { |metric| metric.dig("resource", "name") }.compact
  expected_metrics = spec_metrics.map { |metric| metric.dig("resource", "name") }.compact

  missing_metrics = expected_metrics - metric_names
  if missing_metrics.empty? && !current_metrics.empty?
    append_row(report, "`#{name}`", "runtime metrics populated", "TERMINÉ", "metrics=#{metric_names.join(",")}")
  else
    append_row(report, "`#{name}`", "runtime metrics populated", "PARTIEL", "missing=#{missing_metrics.join(",").empty? ? "all" : missing_metrics.join(",")}")
    failures += 1
  end

  conditions = hpa.dig("status", "conditions") || []
  failed_metric = conditions.find { |condition| condition["reason"].to_s.include?("FailedGet") || condition["message"].to_s.include?("unable to get metrics") }
  if failed_metric
    append_row(report, "`#{name}`", "HPA metric condition", "PARTIEL", "#{failed_metric["type"]}=#{failed_metric["reason"]}")
    failures += 1
  else
    append_row(report, "`#{name}`", "HPA metric condition", "TERMINÉ", "no failed metric condition")
  end
end

exit failures
RUBY
  hpa_failures=$?
  set -e
  failures=$((failures + hpa_failures))
else
  row "HPA" "list namespace" "PARTIEL" "kubectl get hpa failed"
  failures=$((failures + 1))
fi

capture "Kubernetes context" kubectl config current-context
capture "Metrics APIService" kubectl get apiservice v1beta1.metrics.k8s.io -o wide
capture "metrics-server deployment" kubectl get deployment metrics-server -n kube-system -o wide
capture "metrics-server pods" kubectl get pods -n kube-system -l k8s-app=metrics-server -o wide
capture "Node metrics" kubectl top nodes
capture "Pod metrics" kubectl top pods -n "${NS}"
capture "HPA wide" kubectl get hpa -n "${NS}" -o wide
capture "HPA describe" kubectl describe hpa -n "${NS}"

cat >> "${OUT_FILE}" <<'EOF'

## Reading guide

- `TERMINÉ` means the command succeeded and runtime metrics are populated.
- `PARTIEL` means Kubernetes answered but metrics or HPA status are incomplete.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means a reachable cluster or metrics-server is required.
EOF

if [[ "${failures}" -gt 0 ]]; then
  warn "HPA runtime report contains ${failures} gap(s): ${OUT_FILE}"
  [[ "${STRICT}" == "true" ]] && exit 1
else
  info "HPA runtime report passed: ${OUT_FILE}"
fi
