#!/usr/bin/env bash
# File: scripts/ci/policy-as-code.sh
# Description: CI-friendly policy-as-code enforcement with structured output and caching
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

POLICY_DIR="${POLICY_DIR:-${PROJECT_ROOT}/security/conftest/policy}"
CACHE_DIR="${CACHE_DIR:-${PROJECT_ROOT}/.cache/policy-as-code}"
REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/security/reports/policy-as-code}"
FAIL_ON_WARN="${FAIL_ON_WARN:-true}"

VIOLATIONS=0
OUTPUT_JSON="${REPORT_DIR}/results.json"
SUMMARY_JSON="${REPORT_DIR}/summary.json"

mkdir -p "${CACHE_DIR}" "${REPORT_DIR}"

log()   { printf '[INFO]  %s\n' "$*"; }
warn()  { printf '[WARN]  %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_conftest() {
  if ! command -v conftest &>/dev/null; then
    error "conftest is not installed"
    exit 1
  fi
}

require_jq() {
  if ! command -v jq &>/dev/null; then
    error "jq is not installed"
    exit 1
  fi
}

run_policy_check() {
  local name="$1"
  local target="$2"
  local cache_key="${name}-$(sha1sum <<< "${target}" | cut -c1-12)"
  local cache_file="${CACHE_DIR}/${cache_key}.json"
  local output_file="${REPORT_DIR}/${name}.json"

  log "Checking ${name} ..."

  if [ -f "${cache_file}" ] && [ "${CONFTEST_NO_CACHE:-}" != "true" ]; then
    log "  Using cached result: ${cache_file}"
    cp "${cache_file}" "${output_file}"
  else
    set +e
    conftest test "${target}" \
      --policy "${POLICY_DIR}" \
      --all-namespaces \
      --output json \
      --fail-on-warn="${FAIL_ON_WARN}" \
      2>"${REPORT_DIR}/${name}.err" > "${output_file}"
    local exit_code=$?
    set -e

    cp "${output_file}" "${cache_file}"
  fi

  local violations
  violations=$(jq '[.results[]? | select(.failures | length > 0)] | length' "${output_file}" 2>/dev/null || echo 0)

  if [ "$violations" -gt 0 ]; then
    VIOLATIONS=$((VIOLATIONS + violations))
    error "  ${name}: ${violations} violation(s) found"
    jq -c '.results[]? | select(.failures | length > 0) | {file: .filename, failures: [.failures[].message]}' "${output_file}" 2>/dev/null || true
  else
    log "  ${name}: PASS"
  fi

  cat >> "${OUTPUT_JSON}" <<< "$(jq -c --arg name "${name}" '. + {check: $name}' "${output_file}" 2>/dev/null || echo "{\"check\": \"${name}\", \"error\": true}")"
}

generate_summary() {
  cat > "${SUMMARY_JSON}" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_violations": ${VIOLATIONS},
  "status": "$([ "${VIOLATIONS}" -eq 0 ] && echo "pass" || echo "fail")",
  "checks": $(jq -s '.' "${REPORT_DIR}"/*.json 2>/dev/null || echo "[]")
}
EOF
  log "Summary written to ${SUMMARY_JSON}"
}

quality_gate() {
  local max_violations="${MAX_VIOLATIONS:-0}"
  if [ "${VIOLATIONS}" -gt "${max_violations}" ]; then
    error "Quality gate FAILED: ${VIOLATIONS} violations exceed max ${max_violations}"
    exit 1
  fi
  log "Quality gate PASSED: ${VIOLATIONS} violations (max ${max_violations})"
}

require_conftest
require_jq

echo '[]' > "${OUTPUT_JSON}"

if [ -d "${PROJECT_ROOT}/infra/terraform" ]; then
  run_policy_check "terraform" "${PROJECT_ROOT}/infra/terraform/"
fi

if [ -d "${PROJECT_ROOT}/infra/helm" ]; then
  run_policy_check "helm" "${PROJECT_ROOT}/infra/helm/"
fi

if [ -d "${PROJECT_ROOT}/infra/k8s" ]; then
  run_policy_check "k8s" "${PROJECT_ROOT}/infra/k8s/"
fi

if [ -d "${PROJECT_ROOT}/infra/kustomize" ]; then
  run_policy_check "kustomize" "${PROJECT_ROOT}/infra/kustomize/"
fi

generate_summary
quality_gate

exit 0
