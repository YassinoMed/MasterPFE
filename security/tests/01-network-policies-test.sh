#!/usr/bin/env bash
# security/tests/01-network-policies-test.sh
# Tests NetworkPolicies enforcement using the shared framework.

set -euo pipefail

# Source the framework
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-framework.sh"

NAMESPACE="securerag-hub"
init_test_suite "network-policies-validation"

# Helper to check if a pod exists and get its name
get_pod_name() {
  local app_name="$1"
  k get pods -n "${NAMESPACE}" -l app.kubernetes.io/name="${app_name}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

# Helper to perform the connection test
run_connection_test() {
  local test_id="$1"
  local src_app="$2"
  local target_host="$3"
  local target_port="$4"
  local expected="$5" # ALLOW or BLOCK

  local start_time=$(date +%s)
  local src_pod=$(get_pod_name "${src_app}")

  if [ -z "${src_pod}" ]; then
    local end_time=$(date +%s)
    add_test_result "${test_id}" "${src_app} to ${target_host}:${target_port} (${expected})" "FAIL" "$((end_time - start_time))" "Source pod ${src_app} not found in namespace ${NAMESPACE}" ""
    return
  fi

  local status=1
  local cmd_output=""
  set +e
  
  # Try connection using nc or curl (run_with_timeout applies a 30s timeout)
  # We use a 3 second inner timeout for the actual connection attempt
  if k exec -n "${NAMESPACE}" "${src_pod}" -- nc -z -w 3 "${target_host}" "${target_port}" >/dev/null 2>&1; then
    status=0
    cmd_output="Connection successful via nc"
  elif k exec -n "${NAMESPACE}" "${src_pod}" -- curl -s --connect-timeout 3 "http://${target_host}:${target_port}" >/dev/null 2>&1; then
    status=0
    cmd_output="Connection successful via curl"
  else
    status=1
    cmd_output="Connection timed out or failed"
  fi
  set -e

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  if [ "${status}" -eq 0 ]; then
    if [ "${expected}" = "ALLOW" ]; then
      add_test_result "${test_id}" "${src_app} to ${target_host}:${target_port} (Expect: ALLOW)" "PASS" "${duration}" "Connection succeeded as expected." "${cmd_output}"
    else
      add_test_result "${test_id}" "${src_app} to ${target_host}:${target_port} (Expect: BLOCK)" "FAIL" "${duration}" "Connection succeeded but should have been BLOCKED." "${cmd_output}"
    fi
  else
    if [ "${expected}" = "BLOCK" ]; then
      add_test_result "${test_id}" "${src_app} to ${target_host}:${target_port} (Expect: BLOCK)" "PASS" "${duration}" "Connection blocked/timed out as expected." "${cmd_output}"
    else
      add_test_result "${test_id}" "${src_app} to ${target_host}:${target_port} (Expect: ALLOW)" "FAIL" "${duration}" "Connection failed but should have been ALLOWED." "${cmd_output}"
    fi
  fi
}

# 1. Verify that the namespace exists before running tests
if ! k get ns "${NAMESPACE}" >/dev/null 2>&1; then
  add_test_result "NET-00" "Namespace ${NAMESPACE} exists" "FAIL" "0" "Namespace not found, skipping active tests." ""
  finalize_test_suite
fi

add_test_result "NET-00" "Namespace ${NAMESPACE} exists" "PASS" "0" "Namespace verified." ""

# 2. Whitelisted paths (ALLOW)
run_connection_test "NET-01" "portal-web" "auth-users-service" 9000 "ALLOW"
run_connection_test "NET-02" "chatbot-manager-service" "conversation-service" 9000 "ALLOW"
run_connection_test "NET-03" "chatbot-manager-service" "chromadb" 8000 "ALLOW"

# 3. Blocked paths (BLOCK) - Default Deny validation
run_connection_test "NET-04" "portal-web" "conversation-service" 9000 "BLOCK"
run_connection_test "NET-05" "portal-web" "chromadb" 8000 "BLOCK"

# Finish the suite
finalize_test_suite
