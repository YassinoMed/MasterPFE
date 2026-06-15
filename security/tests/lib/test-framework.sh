#!/usr/bin/env bash
# security/tests/lib/test-framework.sh
# Framework for automated DevSecOps security tests with JSON reporting.

set -euo pipefail

# --- Config ---
KUBE_CONTEXT="kind-securerag-dev"
REPORTS_DIR="$(dirname "${BASH_SOURCE[0]}")/../reports"
MAX_TIMEOUT=30

# State variables
FRAMEWORK_TEST_SUITE_NAME=""
FRAMEWORK_REPORT_FILE=""
FRAMEWORK_RESULTS_JSON="[]"
FRAMEWORK_TOTAL_TESTS=0
FRAMEWORK_PASSED_TESTS=0
FRAMEWORK_FAILED_TESTS=0
FRAMEWORK_START_TIME=0

# Ensure reports directory exists
mkdir -p "${REPORTS_DIR}"

# --- Helper Functions ---

# Kubectl wrapper with context
k() {
  kubectl --context="${KUBE_CONTEXT}" "$@"
}

# Run a command with timeout and capture output
run_with_timeout() {
  local cmd=("$@")
  timeout "${MAX_TIMEOUT}s" "${cmd[@]}"
}

# --- JSON Reporting Functions ---

# Initialize a new test suite
init_test_suite() {
  FRAMEWORK_TEST_SUITE_NAME="$1"
  local timestamp=$(date +%Y%m%d-%H%M%S)
  FRAMEWORK_REPORT_FILE="${REPORTS_DIR}/${FRAMEWORK_TEST_SUITE_NAME}-${timestamp}.json"
  FRAMEWORK_START_TIME=$(date +%s)
  
  echo "[INFO] Starting Test Suite: ${FRAMEWORK_TEST_SUITE_NAME}"
  echo "[INFO] Report will be saved to: ${FRAMEWORK_REPORT_FILE}"
}

# Add a test result
# Usage: add_test_result <test_id> <name> <status> <duration_sec> <details> <evidence>
add_test_result() {
  local id="$1"
  local name="$2"
  local status="$3"
  local duration="$4"
  local details="$5"
  local evidence="$6"

  # Escape inputs for JSON
  local escaped_name=$(echo -n "$name" | jq -R -s -c '.')
  local escaped_details=$(echo -n "$details" | jq -R -s -c '.')
  local escaped_evidence=$(echo -n "$evidence" | jq -R -s -c '.')

  local result_json="{\"test_id\": \"$id\", \"name\": $escaped_name, \"status\": \"$status\", \"duration_sec\": $duration, \"details\": $escaped_details, \"evidence\": $escaped_evidence}"

  if [ "$FRAMEWORK_RESULTS_JSON" = "[]" ]; then
    FRAMEWORK_RESULTS_JSON="[$result_json]"
  else
    # Strip trailing bracket and append
    FRAMEWORK_RESULTS_JSON="${FRAMEWORK_RESULTS_JSON%]*},$result_json]"
  fi

  FRAMEWORK_TOTAL_TESTS=$((FRAMEWORK_TOTAL_TESTS + 1))
  if [ "$status" = "PASS" ]; then
    FRAMEWORK_PASSED_TESTS=$((FRAMEWORK_PASSED_TESTS + 1))
    echo "[PASS] ${id}: ${name} (${duration}s)"
  else
    FRAMEWORK_FAILED_TESTS=$((FRAMEWORK_FAILED_TESTS + 1))
    echo "[FAIL] ${id}: ${name} (${duration}s)"
    echo "       Details: $details"
  fi
}

# Finalize the test suite and write the JSON report
finalize_test_suite() {
  local end_time=$(date +%s)
  local total_duration=$((end_time - FRAMEWORK_START_TIME))
  local current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build the final JSON
  jq -n \
    --arg suite "$FRAMEWORK_TEST_SUITE_NAME" \
    --arg ts "$current_timestamp" \
    --arg env "kind" \
    --arg total "$FRAMEWORK_TOTAL_TESTS" \
    --arg passed "$FRAMEWORK_PASSED_TESTS" \
    --arg failed "$FRAMEWORK_FAILED_TESTS" \
    --arg duration "$total_duration" \
    --argjson results "$FRAMEWORK_RESULTS_JSON" \
    '{
      "test_suite": $suite,
      "timestamp": $ts,
      "environment": $env,
      "results": $results,
      "summary": {
        "total": ($total | tonumber),
        "passed": ($passed | tonumber),
        "failed": ($failed | tonumber),
        "duration_sec": ($duration | tonumber)
      }
    }' > "${FRAMEWORK_REPORT_FILE}"

  echo "[INFO] Test Suite Completed in ${total_duration}s. Passed: ${FRAMEWORK_PASSED_TESTS}, Failed: ${FRAMEWORK_FAILED_TESTS}."
  echo "[INFO] Report written to ${FRAMEWORK_REPORT_FILE}"

  if [ "${FRAMEWORK_FAILED_TESTS}" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}
