#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_DIR="${PROJECT_ROOT}/tests/performance"
REPORT_DIR="${PROJECT_ROOT}/reports/k6"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# ── Environment detection ──────────────────────────────────────────────
NAMESPACE="${NAMESPACE:-securerag-hub}"
KUBE_CONTEXT="${KUBE_CONTEXT:-$(kubectl config current-context 2>/dev/null || echo 'local')}"

if kubectl get namespace "${NAMESPACE}" &>/dev/null 2>&1; then
  ENV="kubernetes"
elif [ -n "${BASE_URL:-}" ]; then
  ENV="custom"
else
  ENV="local"
  BASE_URL="${BASE_URL:-http://localhost:30081}"
fi

# ── Script-level defaults (overridable via env) ───────────────────────
K6_BIN="${K6_BIN:-k6}"
K6_VERBOSE="${K6_VERBOSE:-false}"
EXIT_ON_FAIL="${EXIT_ON_FAIL:-true}"
RESULTS_DIR="${RESULTS_DIR:-${REPORT_DIR}/${TIMESTAMP}}"

BASE_URL="${BASE_URL:-}"
AUTH_URL="${AUTH_URL:-}"
CHATBOT_URL="${CHATBOT_URL:-}"
CONVERSATION_URL="${CONVERSATION_URL:-}"
AUDIT_URL="${AUDIT_URL:-}"
GATEWAY_URL="${GATEWAY_URL:-}"

# ── Known test scripts ────────────────────────────────────────────────
TESTS=(
  "${TEST_DIR}/k6-smoke-test.js:smoke"
  "${TEST_DIR}/k6-load-test.js:load"
  "${TEST_DIR}/k6-stress-test.js:stress"
  "${TEST_DIR}/k6-spike-test.js:spike"
  "${TEST_DIR}/k6-endurance-test.js:endurance"
)

# ── Help ──────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [test_name ...]

Options:
  -n, --namespace NS       Kubernetes namespace (default: securerag-hub)
  -b, --base-url URL       Override base URL for all services
  -r, --results-dir DIR    Output directory for results (default: reports/k6/<ts>)
  -v, --verbose            Enable verbose k6 output
  -e, --exit-on-fail       Exit with non-zero on SLO failure (default: true)
  -h, --help               Show this help

Test names (run specific tests):
  smoke      k6-smoke-test.js
  load       k6-load-test.js
  stress     k6-stress-test.js
  spike      k6-spike-test.js
  endurance  k6-endurance-test.js
  all        (default) Run all five test suites

Examples:
  $(basename "$0") all
  $(basename "$0") -n production -b http://portal-web:8000 smoke load
  $(basename "$0") --exit-on-fail false spike
EOF
  exit 0
}

# ── Parse arguments ───────────────────────────────────────────────────
REQUESTED_TESTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    -b|--base-url) BASE_URL="$2"; shift 2 ;;
    -r|--results-dir) RESULTS_DIR="$2"; shift 2 ;;
    -v|--verbose) K6_VERBOSE=true; shift ;;
    -e|--exit-on-fail) EXIT_ON_FAIL="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) REQUESTED_TESTS+=("$1"); shift ;;
  esac
done

if [ ${#REQUESTED_TESTS[@]} -eq 0 ]; then
  REQUESTED_TESTS=("all")
fi

if [[ "${REQUESTED_TESTS[*]}" == "all" ]]; then
  REQUESTED_TESTS=("smoke" "load" "stress" "spike" "endurance")
fi

# ── Build k6 env args ─────────────────────────────────────────────────
K6_ENV_ARGS=()
K6_ENV_ARGS+=("--env" "NAMESPACE=${NAMESPACE}")

if [ -n "${BASE_URL}" ]; then
  K6_ENV_ARGS+=("--env" "BASE_URL=${BASE_URL}")
fi
if [ -n "${AUTH_URL}" ]; then
  K6_ENV_ARGS+=("--env" "AUTH_URL=${AUTH_URL}")
fi
if [ -n "${CHATBOT_URL}" ]; then
  K6_ENV_ARGS+=("--env" "CHATBOT_URL=${CHATBOT_URL}")
fi
if [ -n "${CONVERSATION_URL}" ]; then
  K6_ENV_ARGS+=("--env" "CONVERSATION_URL=${CONVERSATION_URL}")
fi
if [ -n "${AUDIT_URL}" ]; then
  K6_ENV_ARGS+=("--env" "AUDIT_URL=${AUDIT_URL}")
fi
if [ -n "${GATEWAY_URL}" ]; then
  K6_ENV_ARGS+=("--env" "GATEWAY_URL=${GATEWAY_URL}")
fi

K6_RUN_ARGS=("--out" "json=${RESULTS_DIR}/k6-raw.json")
if [ "${K6_VERBOSE}" = "true" ]; then
  K6_RUN_ARGS+=("--verbose")
fi

# ── Run tests ──────────────────────────────────────────────────────────
echo "============================================"
echo "  k6 Performance Suite"
echo "  Environment  : ${ENV}"
echo "  Namespace    : ${NAMESPACE}"
echo "  Results dir  : ${RESULTS_DIR}"
echo "  Tests        : ${REQUESTED_TESTS[*]}"
echo "============================================"

mkdir -p "${RESULTS_DIR}"

PASS_COUNT=0
FAIL_COUNT=0
FAILED_TESTS=()

run_test() {
  local test_script="$1"
  local test_name="$2"

  if [ ! -f "${test_script}" ]; then
    echo "[SKIP] ${test_name} — script not found: ${test_script}"
    return
  fi

  echo ""
  echo "────────────────────────────────────────────"
  echo "  Running: ${test_name}"
  echo "  Script:  ${test_script}"
  echo "────────────────────────────────────────────"

  set +e
  "${K6_BIN}" run \
    "${K6_ENV_ARGS[@]}" \
    "${K6_RUN_ARGS[@]}" \
    --out "json=${RESULTS_DIR}/k6-${test_name}.json" \
    --summary-export="${RESULTS_DIR}/k6-summary-${test_name}.json" \
    "${test_script}"

  K6_EXIT=$?
  set -e

  if [ ${K6_EXIT} -eq 0 ]; then
    echo "[PASS] ${test_name} — all thresholds met"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[FAIL] ${test_name} — thresholds breached (exit=${K6_EXIT})"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_TESTS+=("${test_name}")
  fi
}

for entry in "${TESTS[@]}"; do
  script="${entry%%:*}"
  name="${entry##*:}"

  for requested in "${REQUESTED_TESTS[@]}"; do
    if [ "${requested}" = "${name}" ]; then
      run_test "${script}" "${name}"
    fi
  done
done

# ── Generate aggregate report ──────────────────────────────────────────
{
  echo "{"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"environment\": \"${ENV}\","
  echo "  \"namespace\": \"${NAMESPACE}\","
  echo "  \"tests_requested\": [$(printf '"%s",' "${REQUESTED_TESTS[@]}" | sed 's/,$//')],"
  echo "  \"results\": {"
  echo "    \"passed\": ${PASS_COUNT},"
  echo "    \"failed\": ${FAIL_COUNT},"
  echo "    \"total\": $((PASS_COUNT + FAIL_COUNT))"
  echo "  },"
  echo "  \"failed_tests\": [$(printf '"%s",' "${FAILED_TESTS[@]}" | sed 's/,$//')],"
  echo "  \"slo_passed\": $([ ${FAIL_COUNT} -eq 0 ] && echo 'true' || echo 'false')"
  echo "}"
} > "${RESULTS_DIR}/aggregate-report.json"

echo ""
echo "============================================"
echo "  Suite Complete"
echo "  Passed: ${PASS_COUNT} / Failed: ${FAIL_COUNT}"
echo "  Reports: ${RESULTS_DIR}"
echo "  SLO Gate: $([ ${FAIL_COUNT} -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
echo "============================================"

if [ "${EXIT_ON_FAIL}" = "true" ] && [ ${FAIL_COUNT} -gt 0 ]; then
  exit 1
fi
exit 0
