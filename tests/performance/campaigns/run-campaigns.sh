#!/usr/bin/env bash
# run-campaigns.sh — SecureRAG Hub Performance Campaigns Orchestrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
RUNNER="${PROJECT_ROOT}/scripts/performance/run-k6-tests.sh"

# Campagnes à exécuter (surchargeable : CAMPAIGNS="campaign-300 campaign-600")
CAMPAIGNS="${CAMPAIGNS:-campaign-300 campaign-600 campaign-700 campaign-800 campaign-900}"
# Cooldown entre campagnes en secondes
COOLDOWN="${COOLDOWN:-120}"

echo "========================================================="
# SecureRAG Hub — Multi-Campaign Performance Test Runner
echo "========================================================="
echo "  Executing sequential performance campaigns..."
echo "  Campaigns: ${CAMPAIGNS}"
echo "  Cluster cooldown period: $((COOLDOWN / 60)) minutes between runs."
echo "========================================================="

LAST_CAMPAIGN=""
for c in ${CAMPAIGNS}; do
  LAST_CAMPAIGN="${c}"
done

run_campaign() {
  local target_campaign="$1"
  echo ""
  echo ">>> [START] Campaign: ${target_campaign}"
  bash "${RUNNER}" "${target_campaign}" || true
  echo ">>> [COMPLETED] Campaign: ${target_campaign}"

  if [ "${target_campaign}" != "${LAST_CAMPAIGN}" ]; then
    echo ">>> Waiting $((COOLDOWN / 60)) minutes for cluster resources cooldown..."
    sleep "${COOLDOWN}"
  fi
}

# Run campaigns sequentially
for c in ${CAMPAIGNS}; do
  run_campaign "${c}"
done

echo ""
echo "========================================================="
echo "  All performance campaigns completed!"
echo "  Reports generated in reports/k6/"
echo "========================================================="
