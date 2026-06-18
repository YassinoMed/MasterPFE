#!/usr/bin/env bash
# File: scripts/security/run-conftest.sh
# Description: Run Conftest policy validation on Terraform, Helm, and Kustomize IaC
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

POLICY_DIR="${POLICY_DIR:-${PROJECT_ROOT}/security/conftest/policy}"
REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/security/reports/conftest}"
FAIL_ON_WARN="${FAIL_ON_WARN:-true}"

PASS=0
FAIL=0
ERRORS=()

mkdir -p "${REPORT_DIR}"

log()   { printf '[INFO]  %s\n' "$*"; }
warn()  { printf '[WARN]  %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_conftest() {
  if ! command -v conftest &>/dev/null; then
    error "conftest is not installed. Install from https://www.conftest.dev/"
    exit 1
  fi
}

run_test() {
  local name="$1"
  local target="$2"
  local extra_args="${3:-}"
  local junit_file="${REPORT_DIR}/conftest-${name//\//-}.xml"
  local output_file="${REPORT_DIR}/conftest-${name//\//-}.out"

  log "Validating ${name} ..."
  set +e
  # shellcheck disable=SC2086
  conftest test "${target}" \
    --policy "${POLICY_DIR}" \
    --all-namespaces \
    --output json \
    ${extra_args} \
    2>"${output_file}" | tee "${junit_file}"

  local exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
    PASS=$((PASS + 1))
    log "  PASS: ${name}"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("${name}")
    error "  FAIL: ${name} — see ${output_file}"

    local junit_out="${REPORT_DIR}/junit-${name//\//-}.xml"
    {
      echo '<?xml version="1.0" encoding="UTF-8"?>'
      echo '<testsuite name="conftest" tests="1" failures="1" errors="0">'
      echo '  <testcase name="'"${name}"'">'
      echo '    <failure message="Conftest violation">'
      echo '      Policy violations found in '"${target}"
      echo '    </failure>'
      echo '  </testcase>'
      echo '</testsuite>'
    } > "${junit_out}"
  fi
}

require_conftest

if [ ! -d "${POLICY_DIR}" ]; then
  error "Policy directory not found: ${POLICY_DIR}"
  exit 1
fi

log "Policy dir: ${POLICY_DIR}"
log "Report dir: ${REPORT_DIR}"

if [ -d "${PROJECT_ROOT}/infra/terraform" ]; then
  run_test "terraform" "${PROJECT_ROOT}/infra/terraform/"
else
  warn "infra/terraform/ not found — skipping"
fi

if [ -d "${PROJECT_ROOT}/infra/helm" ]; then
  run_test "helm" "${PROJECT_ROOT}/infra/helm/"
else
  warn "infra/helm/ not found — skipping"
fi

if [ -d "${PROJECT_ROOT}/infra/k8s" ]; then
  run_test "k8s" "${PROJECT_ROOT}/infra/k8s/"
else
  warn "infra/k8s/ not found — skipping"
fi

printf '\n=== Conftest Summary ===\n'
printf 'PASS: %d  FAIL: %d  TOTAL: %d\n' "${PASS}" "${FAIL}" $((PASS + FAIL))

if [ "${#ERRORS[@]}" -gt 0 ]; then
  printf 'FAILURES:\n'
  for e in "${ERRORS[@]}"; do printf '  - %s\n' "${e}"; done
  exit 1
fi

exit 0
