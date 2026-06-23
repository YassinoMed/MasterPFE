#!/usr/bin/env bash
# k6-jenkins-stage.sh
# Jenkins pipeline stage for k6 performance tests with SLO gating.
# Designed to be called from a Jenkins pipeline via `sh`.
#
# Environment variables consumed:
#   NAMESPACE         - Kubernetes namespace (default: securerag-hub)
#   BASE_URL          - Override base URL (optional)
#   K6_TESTS          - Comma-separated test names to run (default: smoke,load,spike,endurance)
#   K6_VERBOSE        - Enable verbose output (default: false)
#   SLO_STRICT        - If "true", fails the pipeline when SLOs are not met (default: true)
#   RESULTS_DIR       - Output directory (default: reports/k6/<timestamp>)
#
# Exit codes:
#   0 - All tests passed SLOs
#   1 - One or more tests failed SLOs (when SLO_STRICT=true)
#   2 - Pre-flight validation failure (k6 not found)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Configuration ──────────────────────────────────────────────────────
NAMESPACE="${NAMESPACE:-securerag-hub}"
K6_TESTS="${K6_TESTS:-smoke,load,spike,endurance}"
K6_VERBOSE="${K6_VERBOSE:-false}"
SLO_STRICT="${SLO_STRICT:-true}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
REPORT_DIR="${PROJECT_ROOT}/reports/k6/${TIMESTAMP}"

# Jenkins build info (empty when run outside Jenkins)
BUILD_ID="${BUILD_ID:-local}"
BUILD_URL="${BUILD_URL:-}"
JOB_NAME="${JOB_NAME:-manual}"

# ── Pre-flight checks ──────────────────────────────────────────────────
echo "[k6-jenkins] Pre-flight checks"

if ! command -v k6 &>/dev/null; then
  echo "[k6-jenkins] WARNING: k6 not found in PATH. Downloading locally..."
  K6_VERSION="v0.56.0"
  curl -fsSLo /tmp/k6.tar.gz "https://github.com/grafana/k6/releases/download/${K6_VERSION}/k6-${K6_VERSION}-linux-amd64.tar.gz"
  tar -xzf /tmp/k6.tar.gz -C /tmp
  export PATH="${PATH}:/tmp/k6-${K6_VERSION}-linux-amd64"
  if ! command -v k6 &>/dev/null; then
    echo "[k6-jenkins] ERROR: k6 dynamic installation failed"
    exit 2
  fi
fi

K6_VERSION=$(k6 version 2>&1 || echo "unknown")
echo "[k6-jenkins] k6 version: ${K6_VERSION}"

# Detect if running inside a Kubernetes pod
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/namespace ]; then
  POD_NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
  echo "[k6-jenkins] Running in Kubernetes namespace: ${POD_NAMESPACE}"
fi

# ── Setup ──────────────────────────────────────────────────────────────
echo "[k6-jenkins] Setting up results directory: ${REPORT_DIR}"
mkdir -p "${REPORT_DIR}"

# Record start time
START_TIME=$(date +%s)

# Convert comma-separated to space-separated
K6_TESTS_SPACE="${K6_TESTS//,/ }"

# ── Run the test suite ────────────────────────────────────────────────
echo "[k6-jenkins] Running tests: ${K6_TESTS_SPACE}"
echo "[k6-jenkins] Namespace: ${NAMESPACE}"
echo "[k6-jenkins] Build: ${JOB_NAME} #${BUILD_ID}"

set +e
"${SCRIPT_DIR}/run-k6-tests.sh" \
  ${K6_VERBOSE:+--verbose} \
  --namespace "${NAMESPACE}" \
  --results-dir "${REPORT_DIR}" \
  --exit-on-fail "${SLO_STRICT}" \
  ${BASE_URL:+--base-url "${BASE_URL}"} \
  ${K6_TESTS_SPACE}

RUN_EXIT=$?
set -e

# ── Record end time ────────────────────────────────────────────────────
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# ── Parse aggregate report ─────────────────────────────────────────────
AGGREGATE="${REPORT_DIR}/aggregate-report.json"
SLO_PASSED="false"
PASS_COUNT=0
FAIL_COUNT=0

if [ -f "${AGGREGATE}" ]; then
  SLO_PASSED=$(jq -r '.slo_passed // false' "${AGGREGATE}")
  PASS_COUNT=$(jq -r '.results.passed // 0' "${AGGREGATE}")
  FAIL_COUNT=$(jq -r '.results.failed // 0' "${AGGREGATE}")

  echo "[k6-jenkins] Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed (duration: ${DURATION}s)"
  echo "[k6-jenkins] SLO Gate: $([ "${SLO_PASSED}" = "true" ] && echo 'PASSED' || echo 'FAILED')"
else
  echo "[k6-jenkins] WARNING: aggregate report not found at ${AGGREGATE}"
fi

# ── Generate Prometheus metrics file (for textfile collector) ──────────
PROM_FILE="${REPORT_DIR}/k6-prometheus.prom"
if [ -f "${REPORT_DIR}/k6-summary-load.json" ]; then
  "${SCRIPT_DIR}/k6-results-to-prometheus.sh" \
    "${REPORT_DIR}/k6-summary-load.json" \
    "${PROM_FILE}" 2>/dev/null || true
  echo "[k6-jenkins] Prometheus metrics written to ${PROM_FILE}"
fi

# ── Generate pipeline summary (machine-readable) ───────────────────────
cat <<EOF > "${REPORT_DIR}/pipeline-summary.json"
{
  "pipeline": {
    "job": "${JOB_NAME}",
    "build_id": "${BUILD_ID}",
    "build_url": "${BUILD_URL}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": ${DURATION}
  },
  "tests": {
    "requested": "${K6_TESTS}",
    "passed": ${PASS_COUNT},
    "failed": ${FAIL_COUNT},
    "total": $((PASS_COUNT + FAIL_COUNT))
  },
  "slo_passed": ${SLO_PASSED},
  "reports_dir": "${REPORT_DIR}"
}
EOF

echo "[k6-jenkins] Pipeline summary: ${REPORT_DIR}/pipeline-summary.json"

# ── Exit / gate ────────────────────────────────────────────────────────
if [ "${SLO_PASSED}" = "true" ]; then
  echo "[k6-jenkins] RESULT: PASSED"
  exit 0
else
  echo "[k6-jenkins] RESULT: FAILED (SLO gate not met)"
  exit 1
fi
