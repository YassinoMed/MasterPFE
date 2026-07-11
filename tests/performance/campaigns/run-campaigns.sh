#!/usr/bin/env bash
# run-campaigns.sh — SecureRAG Hub Performance Campaigns Orchestrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
RUNNER="${PROJECT_ROOT}/scripts/performance/run-k6-tests.sh"

echo "========================================================="
# SecureRAG Hub — Multi-Campaign Performance Test Runner
echo "========================================================="
echo "  Executing sequential performance campaigns..."
echo "  Cluster cooldown period: 2 minutes between runs."
echo "========================================================="

run_campaign() {
  local target_campaign="$1"
  echo ""
  echo ">>> [START] Campaign: ${target_campaign}"
  bash "${RUNNER}" "${target_campaign}" || true
  echo ">>> [COMPLETED] Campaign: ${target_campaign}"
  
  if [ "${target_campaign}" != "campaign-900" ]; then
    echo ">>> Waiting 2 minutes for cluster resources cooldown..."
    sleep 120
  fi
}

# Run the 4 campaigns sequentially
run_campaign campaign-600
run_campaign campaign-700
run_campaign campaign-800
run_campaign campaign-900

echo ""
echo "========================================================="
echo "  All 4 performance campaigns completed!"
echo "  Reports generated in reports/k6/"
echo "========================================================="
