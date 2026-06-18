#!/usr/bin/env bash
# File: scripts/security/run-scorecard.sh
# Description: Run OpenSSF Scorecard analysis
# Modified by: DevSecOps Agent — 2026-06-13

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${CONFIG_DIR:-${PROJECT_ROOT}/security/scorecard}"
REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/security/reports}"
POLICY_FILE="${POLICY_FILE:-${CONFIG_DIR}/scorecard-policy.yaml}"
SCORECARD_ARGS=()

mkdir -p "${REPORT_DIR}"

log()   { printf '[INFO]  %s\n' "$*"; }
warn()  { printf '[WARN]  %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Runs OpenSSF Scorecard analysis on the repository.

Options:
  --local              Run on the local repository (default)
  --repo OWNER/NAME    Run on a specific GitHub repository
  --policy FILE        Path to scorecard policy file
  --output FILE        Path for SARIF results
  --show-details       Show detailed check results
  --help, -h           Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)          SCORECARD_ARGS+=(--local); shift ;;
    --repo)           SCORECARD_ARGS+=(--repo "$2"); shift 2 ;;
    --policy)         POLICY_FILE="$2"; shift 2 ;;
    --output)         SCORECARD_ARGS+=(--output "$2"); REPORT_DIR="$(dirname "$2")"; shift 2 ;;
    --show-details)   SCORECARD_ARGS+=(--show-details); shift ;;
    --help|-h)        usage ;;
    *)                error "Unknown arg: $1"; usage ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command not found: $1"
    exit 1
  fi
}

require_command scorecard

log "Starting OpenSSF Scorecard analysis..."
log "Policy file: ${POLICY_FILE}"
log "Report dir: ${REPORT_DIR}"

sarif_output="${REPORT_DIR}/scorecard-results.sarif"

# Run Scorecard with SARIF output
scorecard \
  --policy="${POLICY_FILE}" \
  --show-details \
  --format=sarif \
  --output="${sarif_output}" \
  "${SCORECARD_ARGS[@]}"

log "Scorecard results written to ${sarif_output}"

# Check policy compliance
log "Checking policy compliance..."
if scorecard --policy="${POLICY_FILE}" --format=json "${SCORECARD_ARGS[@]}" > "${REPORT_DIR}/scorecard-results.json" 2>&1; then
  log "Policy validation completed successfully"
else
  warn "Policy violations detected — review ${sarif_output}"
fi

exit 0
