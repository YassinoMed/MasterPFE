#!/usr/bin/env bash
# File: scripts/security/run-conftest.sh
# Description: Run Conftest validation on all Kubernetes manifests
# Modified by: DevSecOps Agent — 2026-06-13

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CONFTEST_CONFIG="${CONFTEST_CONFIG:-${PROJECT_ROOT}/security/conftest/conftest-config.yaml}"
POLICY_DIR="${POLICY_DIR:-${PROJECT_ROOT}/security/conftest/policy}"
MANIFEST_DIR="${MANIFEST_DIR:-${PROJECT_ROOT}/infra/k8s}"
REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/security/reports/conftest}"
FAIL_ON_WARN="${FAIL_ON_WARN:-true}"
COMBINE="${COMBINE:-false}"
PARALLELISM="${PARALLELISM:-4}"

pass_count=0
fail_count=0
skip_count=0

mkdir -p "${REPORT_DIR}"

log()   { printf '[INFO]  %s\n' "$*"; }
warn()  { printf '[WARN]  %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs Conftest policy validation on all Kubernetes manifests.

Options:
  --manifest-dir DIR   Directory containing Kubernetes manifests (default: infra/k8s)
  --policy-dir DIR     Directory containing Rego policies (default: security/conftest/policy)
  --config FILE        Conftest configuration file
  --report-dir DIR     Output directory for reports
  --no-fail-warn       Do not fail on warnings
  --combine            Combine all namespaces into a single decision
  --help, -h           Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest-dir)  MANIFEST_DIR="$2";   shift 2 ;;
    --policy-dir)    POLICY_DIR="$2";     shift 2 ;;
    --config)        CONFTEST_CONFIG="$2"; shift 2 ;;
    --report-dir)    REPORT_DIR="$2";     shift 2 ;;
    --no-fail-warn)  FAIL_ON_WARN="false"; shift ;;
    --combine)       COMBINE="true";      shift ;;
    --parallelism)   PARALLELISM="$2";    shift 2 ;;
    --help|-h)       usage ;;
    *)               error "Unknown arg: $1"; usage ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command not found: $1"
    exit 1
  fi
}

require_command conftest

if [ ! -d "${POLICY_DIR}" ]; then
  error "Policy directory not found: ${POLICY_DIR}"
  exit 1
fi

if [ ! -d "${MANIFEST_DIR}" ]; then
  error "Manifest directory not found: ${MANIFEST_DIR}"
  exit 1
fi

log "Conftest configuration:"
log "  Policy dir: ${POLICY_DIR}"
log "  Manifest dir: ${MANIFEST_DIR}"
log "  Report dir: ${REPORT_DIR}"
log "  Config: ${CONFTEST_CONFIG}"
log "  Fail on warn: ${FAIL_ON_WARN}"
log "  Combine: ${COMBINE}"

# Discover all YAML files
manifest_files=()
while IFS= read -r -d '' f; do
  manifest_files+=("$f")
done < <(find "${MANIFEST_DIR}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

if [[ ${#manifest_files[@]} -eq 0 ]]; then
  warn "No Kubernetes manifest files found in ${MANIFEST_DIR}"
  exit 0
fi

log "Found ${#manifest_files[@]} manifest file(s) in ${MANIFEST_DIR}"

summary_file="${REPORT_DIR}/conftest-summary.txt"
failures_file="${REPORT_DIR}/conftest-failures.txt"
: > "${summary_file}"
: > "${failures_file}"

conftest_args=(
  "--policy" "${POLICY_DIR}"
)

if [ "${FAIL_ON_WARN}" = "true" ]; then
  conftest_args+=("--fail-on-warn")
fi

if [ "${COMBINE}" = "true" ]; then
  conftest_args+=("--combine")
fi

if [ -f "${CONFTEST_CONFIG}" ]; then
  conftest_args+=("--config" "${CONFTEST_CONFIG}")
fi

# Run conftest per file for granular reporting
for manifest in "${manifest_files[@]}"; do
  rel_path="${manifest#${PROJECT_ROOT}/}"
  log "Checking ${rel_path}..."

  if conftest test "${manifest}" "${conftest_args[@]}" > "${REPORT_DIR}/$(basename "${manifest}").conftest" 2>&1; then
    pass_count=$((pass_count + 1))
    printf '%-6s | %s\n' "PASS" "${rel_path}" >> "${summary_file}"
  else
    fail_count=$((fail_count + 1))
    printf '%-6s | %s\n' "FAIL" "${rel_path}" >> "${summary_file}"
    printf 'FAIL | %s\n' "${rel_path}" >> "${failures_file}"
    cat "${REPORT_DIR}/$(basename "${manifest}").conftest" >> "${failures_file}"
    printf '\n---\n' >> "${failures_file}"
  fi
done

{
  printf '\n--- SUMMARY ---\n'
  printf 'PASS: %s\n' "${pass_count}"
  printf 'FAIL: %s\n' "${fail_count}"
  printf 'SKIP: %s\n' "${skip_count}"
  printf 'TOTAL: %s\n' "$(( pass_count + fail_count + skip_count ))"
} >> "${summary_file}"

printf '\n[INFO] Conftest validation completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}"
log "Summary: ${summary_file}"
log "Failures: ${failures_file}"

if (( fail_count > 0 )); then
  error "${fail_count} violation(s) found — review ${failures_file}"
  exit 1
fi

exit 0
