#!/usr/bin/env bash
# performance-quality-gate.sh
# ═══════════════════════════════════════════════════════════════════════
# Performance Quality Gate Evaluator for SecureRAG Hub
# ═══════════════════════════════════════════════════════════════════════
#
# Evaluates k6 test results against the following quality gates:
#   • p95 latency  < 200ms
#   • error rate   < 1%   (0.01)
#   • availability > 99%  (error rate < 0.01)
#
# Generates:
#   1. reports/k6/performance-gate-report.md  — human-readable Markdown
#   2. reports/k6/performance-gate-result.json — machine-readable JSON
#
# Exit codes:
#   0 — All quality gates passed
#   1 — One or more quality gates breached → PIPELINE MUST FAIL
#   2 — Input validation error
#
# Usage:
#   bash scripts/performance/performance-quality-gate.sh [RESULTS_DIR]
#   bash scripts/performance/performance-quality-gate.sh reports/k6/20260623120000
#
# Environment variables:
#   P95_THRESHOLD_MS    — p95 latency threshold in ms (default: 200)
#   ERROR_RATE_THRESHOLD — max error rate as decimal (default: 0.01)
#   AVAILABILITY_THRESHOLD — min availability percentage (default: 99.0)
#   DRY_RUN             — if "true", never exits with code 1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Configuration ──────────────────────────────────────────────────────
P95_THRESHOLD_MS="${P95_THRESHOLD_MS:-200}"
ERROR_RATE_THRESHOLD="${ERROR_RATE_THRESHOLD:-0.01}"
AVAILABILITY_THRESHOLD="${AVAILABILITY_THRESHOLD:-99.0}"
DRY_RUN="${DRY_RUN:-false}"

# ── Locate results ────────────────────────────────────────────────────
RESULTS_DIR="${1:-}"
if [ -z "${RESULTS_DIR}" ]; then
  # Find the most recent k6 results directory
  RESULTS_DIR=$(find "${PROJECT_ROOT}/reports/k6" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -1)
fi

if [ -z "${RESULTS_DIR}" ] || [ ! -d "${RESULTS_DIR}" ]; then
  echo "[PERF-GATE] ERROR: No results directory found"
  echo "[PERF-GATE] Usage: $(basename "$0") <results-dir>"
  exit 2
fi

echo "════════════════════════════════════════════════════════════════"
echo "  Performance Quality Gate Evaluation"
echo "  Results:      ${RESULTS_DIR}"
echo "  p95 Gate:     < ${P95_THRESHOLD_MS}ms"
echo "  Error Gate:   < $(echo "${ERROR_RATE_THRESHOLD} * 100" | bc 2>/dev/null || echo "${ERROR_RATE_THRESHOLD}")%"
echo "  Availability: > ${AVAILABILITY_THRESHOLD}%"
echo "════════════════════════════════════════════════════════════════"

# ── Pre-flight: check for jq ──────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "[PERF-GATE] ERROR: jq is required but not installed"
  exit 2
fi

# ── Aggregate metrics from all test summaries ─────────────────────────
GATE_PASSED=true
GATE_DETAILS=()
P95_VALUES=()
ERROR_RATES=()
TOTAL_REQUESTS=0
FAILED_REQUESTS=0
TESTS_FOUND=0

for summary_file in "${RESULTS_DIR}"/k6-summary-*.json; do
  [ -f "${summary_file}" ] || continue
  TESTS_FOUND=$((TESTS_FOUND + 1))

  TEST_NAME=$(basename "${summary_file}" | sed 's/k6-summary-//' | sed 's/\.json//')
  echo ""
  echo "────────────────────────────────────────────────────────────"
  echo "  Evaluating: ${TEST_NAME}"
  echo "────────────────────────────────────────────────────────────"

  # Extract metrics
  P95=$(jq -r '.metrics.http_req_duration.values."p(95)" // -1' "${summary_file}" 2>/dev/null)
  P99=$(jq -r '.metrics.http_req_duration.values."p(99)" // -1' "${summary_file}" 2>/dev/null)
  AVG=$(jq -r '.metrics.http_req_duration.values.avg // -1' "${summary_file}" 2>/dev/null)
  MAX=$(jq -r '.metrics.http_req_duration.values.max // -1' "${summary_file}" 2>/dev/null)
  REQS=$(jq -r '.metrics.http_reqs.values.count // 0' "${summary_file}" 2>/dev/null)
  ERR_RATE=$(jq -r '.metrics.http_req_failed.values.rate // 0' "${summary_file}" 2>/dev/null)

  # Validate numbers
  [[ "${P95}" =~ ^-?[0-9]+\.?[0-9]*$ ]] || P95=-1
  [[ "${ERR_RATE}" =~ ^-?[0-9]+\.?[0-9]*$ ]] || ERR_RATE=0
  [[ "${REQS}" =~ ^[0-9]+$ ]] || REQS=0

  TOTAL_REQUESTS=$((TOTAL_REQUESTS + REQS))
  P95_VALUES+=("${P95}")
  ERROR_RATES+=("${ERR_RATE}")

  # Calculate availability
  AVAILABILITY=$(echo "scale=4; (1 - ${ERR_RATE}) * 100" | bc 2>/dev/null || echo "0")

  echo "  Requests:      ${REQS}"
  echo "  Avg latency:   ${AVG}ms"
  echo "  p95 latency:   ${P95}ms (gate: < ${P95_THRESHOLD_MS}ms)"
  echo "  p99 latency:   ${P99}ms"
  echo "  Max latency:   ${MAX}ms"
  echo "  Error rate:    ${ERR_RATE} (gate: < ${ERROR_RATE_THRESHOLD})"
  echo "  Availability:  ${AVAILABILITY}% (gate: > ${AVAILABILITY_THRESHOLD}%)"

  # ── Gate 1: p95 latency ───────────────────────────────────────
  # Only evaluate for smoke/load tests (not stress/spike)
  if [[ "${TEST_NAME}" =~ ^(smoke|load)$ ]] && [ "${P95}" != "-1" ]; then
    P95_BREACH=$(echo "${P95} > ${P95_THRESHOLD_MS}" | bc 2>/dev/null || echo "0")
    if [ "${P95_BREACH}" = "1" ]; then
      echo "  ❌ GATE BREACH: p95 ${P95}ms > ${P95_THRESHOLD_MS}ms"
      GATE_PASSED=false
      GATE_DETAILS+=("${TEST_NAME}: p95=${P95}ms > ${P95_THRESHOLD_MS}ms")
    else
      echo "  ✅ p95 latency gate PASSED"
    fi
  fi

  # ── Gate 2: error rate ────────────────────────────────────────
  if [[ "${TEST_NAME}" =~ ^(smoke|load)$ ]]; then
    ERR_BREACH=$(echo "${ERR_RATE} > ${ERROR_RATE_THRESHOLD}" | bc 2>/dev/null || echo "0")
    if [ "${ERR_BREACH}" = "1" ]; then
      echo "  ❌ GATE BREACH: error rate ${ERR_RATE} > ${ERROR_RATE_THRESHOLD}"
      GATE_PASSED=false
      GATE_DETAILS+=("${TEST_NAME}: error_rate=${ERR_RATE} > ${ERROR_RATE_THRESHOLD}")
    else
      echo "  ✅ Error rate gate PASSED"
    fi
  fi

  # ── Gate 3: availability ──────────────────────────────────────
  if [[ "${TEST_NAME}" =~ ^(smoke|load)$ ]]; then
    AVAIL_BREACH=$(echo "${AVAILABILITY} < ${AVAILABILITY_THRESHOLD}" | bc 2>/dev/null || echo "0")
    if [ "${AVAIL_BREACH}" = "1" ]; then
      echo "  ❌ GATE BREACH: availability ${AVAILABILITY}% < ${AVAILABILITY_THRESHOLD}%"
      GATE_PASSED=false
      GATE_DETAILS+=("${TEST_NAME}: availability=${AVAILABILITY}% < ${AVAILABILITY_THRESHOLD}%")
    else
      echo "  ✅ Availability gate PASSED"
    fi
  fi
done

if [ ${TESTS_FOUND} -eq 0 ]; then
  echo "[PERF-GATE] WARNING: No k6 summary files found in ${RESULTS_DIR}"
  exit 2
fi

# ── Calculate aggregated worst-case metrics ────────────────────────────
WORST_P95=0
for p in "${P95_VALUES[@]}"; do
  IS_WORSE=$(echo "${p} > ${WORST_P95}" | bc 2>/dev/null || echo "0")
  if [ "${IS_WORSE}" = "1" ]; then
    WORST_P95="${p}"
  fi
done

WORST_ERR=0
for e in "${ERROR_RATES[@]}"; do
  IS_WORSE=$(echo "${e} > ${WORST_ERR}" | bc 2>/dev/null || echo "0")
  if [ "${IS_WORSE}" = "1" ]; then
    WORST_ERR="${e}"
  fi
done

BEST_AVAILABILITY=$(echo "scale=4; (1 - ${WORST_ERR}) * 100" | bc 2>/dev/null || echo "0")

# ── Generate Markdown report ──────────────────────────────────────────
REPORT_DIR="${PROJECT_ROOT}/reports/k6"
mkdir -p "${REPORT_DIR}"
REPORT_FILE="${REPORT_DIR}/performance-gate-report.md"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GATE_STATUS="PASSED"
GATE_EMOJI="✅"
if [ "${GATE_PASSED}" != "true" ]; then
  GATE_STATUS="FAILED"
  GATE_EMOJI="❌"
fi

cat > "${REPORT_FILE}" <<EOF
# Performance Quality Gate Report — SecureRAG Hub

- **Generated at UTC**: \`${TIMESTAMP}\`
- **Results directory**: \`${RESULTS_DIR}\`
- **Overall Status**: \`${GATE_STATUS}\` (${GATE_EMOJI})

## Quality Gate Thresholds

| Gate | Threshold | Worst Observed | Status |
|---|---|---|---|
| p95 Latency | < ${P95_THRESHOLD_MS}ms | ${WORST_P95}ms | $([ "${GATE_PASSED}" = "true" ] && echo "✅ PASS" || echo "❌ FAIL") |
| Error Rate | < $(echo "${ERROR_RATE_THRESHOLD} * 100" | bc 2>/dev/null || echo "${ERROR_RATE_THRESHOLD}")% | $(echo "scale=4; ${WORST_ERR} * 100" | bc 2>/dev/null || echo "${WORST_ERR}")% | $(echo "${WORST_ERR} <= ${ERROR_RATE_THRESHOLD}" | bc 2>/dev/null | grep -q "1" && echo "✅ PASS" || echo "❌ FAIL") |
| Availability | > ${AVAILABILITY_THRESHOLD}% | ${BEST_AVAILABILITY}% | $(echo "${BEST_AVAILABILITY} >= ${AVAILABILITY_THRESHOLD}" | bc 2>/dev/null | grep -q "1" && echo "✅ PASS" || echo "❌ FAIL") |

## Test Summary

| Metric | Value |
|---|---|
| Tests evaluated | ${TESTS_FOUND} |
| Total requests | ${TOTAL_REQUESTS} |
| Worst p95 | ${WORST_P95}ms |
| Worst error rate | $(echo "scale=4; ${WORST_ERR} * 100" | bc 2>/dev/null || echo "${WORST_ERR}")% |
| Lowest availability | ${BEST_AVAILABILITY}% |
EOF

if [ "${GATE_PASSED}" != "true" ]; then
  {
    echo ""
    echo "## Gate Breaches"
    echo ""
    for detail in "${GATE_DETAILS[@]}"; do
      echo "- ❌ ${detail}"
    done
  } >> "${REPORT_FILE}"
fi

{
  echo ""
  echo "## Per-Test Details"
  echo ""
  for summary_file in "${RESULTS_DIR}"/k6-summary-*.json; do
    [ -f "${summary_file}" ] || continue
    TEST_NAME=$(basename "${summary_file}" | sed 's/k6-summary-//' | sed 's/\.json//')
    P95=$(jq -r '.metrics.http_req_duration.values."p(95)" // "N/A"' "${summary_file}" 2>/dev/null)
    P99=$(jq -r '.metrics.http_req_duration.values."p(99)" // "N/A"' "${summary_file}" 2>/dev/null)
    AVG=$(jq -r '.metrics.http_req_duration.values.avg // "N/A"' "${summary_file}" 2>/dev/null)
    REQS=$(jq -r '.metrics.http_reqs.values.count // "N/A"' "${summary_file}" 2>/dev/null)
    ERR=$(jq -r '.metrics.http_req_failed.values.rate // "N/A"' "${summary_file}" 2>/dev/null)
    echo "### ${TEST_NAME}"
    echo ""
    echo "| Metric | Value |"
    echo "|---|---|"
    echo "| Requests | ${REQS} |"
    echo "| Avg latency | ${AVG}ms |"
    echo "| p95 latency | ${P95}ms |"
    echo "| p99 latency | ${P99}ms |"
    echo "| Error rate | ${ERR} |"
    echo ""
  done
} >> "${REPORT_FILE}"

echo "[PERF-GATE] Report written to ${REPORT_FILE}"

# ── Generate JSON result ──────────────────────────────────────────────
JSON_FILE="${REPORT_DIR}/performance-gate-result.json"
cat > "${JSON_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "results_dir": "${RESULTS_DIR}",
  "gate_passed": ${GATE_PASSED},
  "status": "${GATE_STATUS}",
  "thresholds": {
    "p95_latency_ms": ${P95_THRESHOLD_MS},
    "error_rate": ${ERROR_RATE_THRESHOLD},
    "availability_pct": ${AVAILABILITY_THRESHOLD}
  },
  "observed": {
    "worst_p95_ms": ${WORST_P95},
    "worst_error_rate": ${WORST_ERR},
    "best_availability_pct": ${BEST_AVAILABILITY},
    "total_requests": ${TOTAL_REQUESTS},
    "tests_evaluated": ${TESTS_FOUND}
  },
  "breaches": [$(printf '"%s",' "${GATE_DETAILS[@]}" 2>/dev/null | sed 's/,$//')]
}
EOF

echo "[PERF-GATE] JSON result written to ${JSON_FILE}"

# ── Final verdict ─────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
if [ "${GATE_PASSED}" = "true" ]; then
  echo "  ✅ PERFORMANCE QUALITY GATE: PASSED"
  echo "════════════════════════════════════════════════════════════════"
  exit 0
else
  echo "  ❌ PERFORMANCE QUALITY GATE: FAILED"
  echo ""
  for detail in "${GATE_DETAILS[@]}"; do
    echo "    • ${detail}"
  done
  echo "════════════════════════════════════════════════════════════════"
  if [ "${DRY_RUN}" = "true" ]; then
    echo "[PERF-GATE] DRY_RUN=true — not failing pipeline"
    exit 0
  fi
  exit 1
fi
