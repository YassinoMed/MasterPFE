#!/usr/bin/env bash
# parse-falco.sh — Parse Falco alerts for Quality Gate
# SecureRAG Hub — World-Class Runtime Security
#
# Reads Falco alert files and determines if critical alerts exist.
# Falcons alerts are expected in security/reports/falco-alerts.json
#
# Usage:
#   bash scripts/ci/parse-falco.sh
#
# Exit codes:
#   0 = No critical alerts
#   1 = Critical alerts found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FALCO_ALERTS="${REPO_ROOT}/security/reports/falco-alerts.json"
FALCO_SUMMARY="${REPO_ROOT}/artifacts/security/falco-summary.md"

mkdir -p "$(dirname "${FALCO_SUMMARY}")"

CRITICAL=0
HIGH=0
WARNING=0

if [ -f "${FALCO_ALERTS}" ] && [ -s "${FALCO_ALERTS}" ]; then
  if command -v jq &>/dev/null; then
    CRITICAL=$(jq '[.[] | select(.priority=="CRITICAL" or .priority=="Emergency")] | length' "${FALCO_ALERTS}" 2>/dev/null || echo 0)
    HIGH=$(jq '[.[] | select(.priority=="HIGH" or .priority=="Error")] | length' "${FALCO_ALERTS}" 2>/dev/null || echo 0)
    WARNING=$(jq '[.[] | select(.priority=="WARNING" or .priority=="Warning")] | length' "${FALCO_ALERTS}" 2>/dev/null || echo 0)
  else
    CRITICAL=$(grep -c '"priority":"CRITICAL"\|"priority":"Emergency"' "${FALCO_ALERTS}" 2>/dev/null || echo 0)
    HIGH=$(grep -c '"priority":"HIGH"\|"priority":"Error"' "${FALCO_ALERTS}" 2>/dev/null || echo 0)
  fi
fi

{
  echo "# Falco Runtime Alert Summary"
  echo "_Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_"
  echo ""
  echo "| Severity | Count |"
  echo "|----------|:-----:|"
  echo "| 🔴 CRITICAL | ${CRITICAL} |"
  echo "| 🟠 HIGH | ${HIGH} |"
  echo "| 🟡 WARNING | ${WARNING} |"
  echo ""
  if [ -f "${FALCO_ALERTS}" ]; then
    echo "**Report:** ${FALCO_ALERTS}"
  else
    echo "**Status:** No Falco report available (runtime cluster only)"
  fi
} > "${FALCO_SUMMARY}"

echo "Falco: ${CRITICAL} CRITICAL, ${HIGH} HIGH, ${WARNING} WARNING"

[ "${CRITICAL}" -eq 0 ] || exit 1
exit 0
