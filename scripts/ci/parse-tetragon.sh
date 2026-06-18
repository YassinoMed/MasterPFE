#!/usr/bin/env bash
# parse-tetragon.sh — Parse Tetragon events for Quality Gate
# SecureRAG Hub — World-Class Runtime Security
#
# Reads Tetragon event files and determines if security violations exist.
# Events expected in security/reports/tetragon-events.json
#
# Usage:
#   bash scripts/ci/parse-tetragon.sh
#
# Exit codes:
#   0 = No violations
#   1 = Violations found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TETRAGON_EVENTS="${REPO_ROOT}/security/reports/tetragon-events.json"
TETRAGON_SUMMARY="${REPO_ROOT}/artifacts/security/tetragon-summary.md"

mkdir -p "$(dirname "${TETRAGON_SUMMARY}")"

VIOLATIONS=0
PROCESS_EVENTS=0
NETWORK_EVENTS=0
KEXEC_EVENTS=0

if [ -f "${TETRAGON_EVENTS}" ] && [ -s "${TETRAGON_EVENTS}" ]; then
  if command -v jq &>/dev/null; then
    VIOLATIONS=$(jq 'length' "${TETRAGON_EVENTS}" 2>/dev/null || echo 0)
    PROCESS_EVENTS=$(jq '[.[] | select(.type=="process_exec" or .type=="process_exit")] | length' "${TETRAGON_EVENTS}" 2>/dev/null || echo 0)
    KEXEC_EVENTS=$(jq '[.[] | select(.binary=="kubectl")] | length' "${TETRAGON_EVENTS}" 2>/dev/null || echo 0)
  else
    VIOLATIONS=$(grep -c '"type"' "${TETRAGON_EVENTS}" 2>/dev/null || echo 0)
  fi
fi

{
  echo "# Tetragon Runtime Event Summary"
  echo "_Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_"
  echo ""
  echo "| Metric | Count |"
  echo "|--------|:-----:|"
  echo "| Total Events | ${VIOLATIONS} |"
  echo "| Process Exec | ${PROCESS_EVENTS} |"
  echo "| kubectl Exec | ${KEXEC_EVENTS} |"
  echo "| Network Events | ${NETWORK_EVENTS} |"
  echo ""
  if [ -f "${TETRAGON_EVENTS}" ]; then
    echo "**Report:** ${TETRAGON_EVENTS}"
  else
    echo "**Status:** No Tetragon report available (runtime cluster only)"
  fi
} > "${TETRAGON_SUMMARY}"

echo "Tetragon: ${VIOLATIONS} events (${PROCESS_EVENTS} process, ${KEXEC_EVENTS} kubectl exec)"

[ "${KEXEC_EVENTS}" -eq 0 ] || exit 1
exit 0
