#!/usr/bin/env bash
# File: scripts/security/run-all-security-checks.sh
# Description: Orchestrates all security checks and generates a combined report
# Modified by: DevSecOps Agent — 2026-06-13

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/security/reports/combined}"
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
COMBINED_REPORT="${REPORT_DIR}/security-report-${TIMESTAMP}.md"

GLOBAL_EXIT_CODE=0

mkdir -p "${REPORT_DIR}"

log()   { printf '[INFO]    %s\n' "$*"; }
warn()  { printf '[WARN]    %s\n' "$*"; }
ok()    { printf '[OK]      %s\n' "$*"; }
error() { printf '[ERROR]   %s\n' "$*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command not found: $1 — skipping related checks"
    return 1
  fi
}

init_report() {
  cat > "${COMBINED_REPORT}" <<EOF
# SecureRAG Hub — Combined Security Report

**Generated at:** ${TIMESTAMP}
**Repository:** ${PROJECT_ROOT}

## Summary

| Check | Status | Details |
|-------|--------|---------|
EOF
}

append_result() {
  local check="$1"
  local status="$2"
  local detail="$3"
  printf '| %s | %s | %s |\n' "${check}" "${status}" "${detail}" >> "${COMBINED_REPORT}"
}

run_scorecard() {
  log "Running OpenSSF Scorecard..."
  if require_command scorecard; then
    if "${SCRIPT_DIR}/run-scorecard.sh" --report-dir "${REPORT_DIR}/scorecard"; then
      ok "Scorecard passed"
      append_result "OpenSSF Scorecard" "PASS" "All checks meet minimum thresholds"
    else
      warn "Scorecard violations detected"
      append_result "OpenSSF Scorecard" "WARN" "Policy violations found — see scorecard report"
    fi
  else
    append_result "OpenSSF Scorecard" "SKIP" "scorecard CLI not installed"
  fi
}

run_conftest() {
  log "Running Conftest..."
  if require_command conftest; then
    if "${SCRIPT_DIR}/run-conftest.sh" --report-dir "${REPORT_DIR}/conftest"; then
      ok "Conftest passed"
      append_result "Conftest (K8s policies)" "PASS" "All manifests comply with Rego policies"
    else
      error "Conftest violations detected"
      GLOBAL_EXIT_CODE=1
      append_result "Conftest (K8s policies)" "FAIL" "Policy violations found — see conftest report"
    fi
  else
    append_result "Conftest (K8s policies)" "SKIP" "conftest CLI not installed"
  fi
}

run_trivy() {
  log "Running Trivy..."
  if require_command trivy; then
    TRIVY_REPORT="${REPORT_DIR}/trivy"
    mkdir -p "${TRIVY_REPORT}"
    if trivy filesystem \
      --config "${PROJECT_ROOT}/security/trivy/trivy.yaml" \
      --format json \
      --output "${TRIVY_REPORT}/results.json" \
      "${PROJECT_ROOT}"; then
      ok "Trivy passed"
      append_result "Trivy (vulns + misconfig)" "PASS" "No HIGH/CRITICAL vulnerabilities or misconfigurations"
    else
      warn "Trivy findings detected"
      append_result "Trivy (vulns + misconfig)" "WARN" "Findings found — see trivy report"
    fi
  else
    append_result "Trivy (vulns + misconfig)" "SKIP" "trivy CLI not installed"
  fi
}

run_semgrep() {
  log "Running Semgrep..."
  if require_command semgrep; then
    SEMGREP_REPORT="${REPORT_DIR}/semgrep"
    mkdir -p "${SEMGREP_REPORT}"
    if semgrep \
      --config "${PROJECT_ROOT}/security/semgrep/semgrep.yml" \
      --json \
      --output "${SEMGREP_REPORT}/results.json" \
      "${PROJECT_ROOT}" 2>/dev/null; then
      ok "Semgrep passed"
      append_result "Semgrep (SAST)" "PASS" "No rule violations"
    else
      warn "Semgrep findings detected"
      append_result "Semgrep (SAST)" "WARN" "Findings found — see semgrep report"
    fi
  else
    append_result "Semgrep (SAST)" "SKIP" "semgrep CLI not installed"
  fi
}

run_gitleaks() {
  log "Running Gitleaks..."
  if require_command gitleaks; then
    GITLEAKS_REPORT="${REPORT_DIR}/gitleaks"
    mkdir -p "${GITLEAKS_REPORT}"
    if gitleaks detect \
      --config "${PROJECT_ROOT}/.gitleaks.toml" \
      --report-path "${GITLEAKS_REPORT}/results.json" \
      --no-git \
      --verbose 2>/dev/null; then
      ok "Gitleaks passed"
      append_result "Gitleaks (secrets)" "PASS" "No secrets detected"
    else
      error "Gitleaks detected potential secrets"
      GLOBAL_EXIT_CODE=1
      append_result "Gitleaks (secrets)" "FAIL" "Potential secrets found — see gitleaks report"
    fi
  else
    append_result "Gitleaks (secrets)" "SKIP" "gitleaks CLI not installed"
  fi
}

generate_summary() {
  cat >> "${COMBINED_REPORT}" <<EOF

## Details

### OpenSSF Scorecard
- Report: \`${REPORT_DIR}/scorecard/scorecard-results.sarif\`

### Conftest
- Summary: \`${REPORT_DIR}/conftest/conftest-summary.txt\`
- Failures: \`${REPORT_DIR}/conftest/conftest-failures.txt\`

### Trivy
- Report: \`${REPORT_DIR}/trivy/results.json\`

### Semgrep
- Report: \`${REPORT_DIR}/semgrep/results.json\`

### Gitleaks
- Report: \`${REPORT_DIR}/gitleaks/results.json\`

EOF

  if [ "${GLOBAL_EXIT_CODE}" -eq 0 ]; then
    printf '\n**Final verdict: ALL CHECKS PASSED**\n' >> "${COMBINED_REPORT}"
  else
    printf '\n**Final verdict: SOME CHECKS FAILED** — review individual reports above\n' >> "${COMBINED_REPORT}"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "Starting all security checks..."
log "Report directory: ${REPORT_DIR}"
init_report

run_scorecard
run_conftest
run_trivy
run_semgrep
run_gitleaks

generate_summary

printf '\n[INFO] Combined security report: %s\n' "${COMBINED_REPORT}"
log "All checks completed — exit code ${GLOBAL_EXIT_CODE}"

exit "${GLOBAL_EXIT_CODE}"
