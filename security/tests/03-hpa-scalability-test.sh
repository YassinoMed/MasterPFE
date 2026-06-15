#!/usr/bin/env bash
# security/tests/03-hpa-scalability-test.sh
# Tests Horizontal Pod Autoscalers to ensure targets are defined and active.

set -euo pipefail

# Source the framework
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-framework.sh"

NAMESPACE="securerag-hub"
init_test_suite "hpa-scalability-validation"

echo "[INFO] Checking metrics-server availability..."
start_time=$(date +%s)
set +e
k get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1
status=$?
set -e
duration=$(( $(date +%s) - start_time ))

if [ $status -eq 0 ]; then
  add_test_result "HPA-00" "Metrics Server API available" "PASS" "${duration}" "v1beta1.metrics.k8s.io API is available." ""
else
  add_test_result "HPA-00" "Metrics Server API available" "FAIL" "${duration}" "Metrics API not found. HPA will not function correctly." ""
  finalize_test_suite
fi

echo "[INFO] Fetching HPA resources in ${NAMESPACE}..."
start_time=$(date +%s)
set +e
hpa_list=$(k get hpa -n "${NAMESPACE}" -o json)
status=$?
set -e
duration=$(( $(date +%s) - start_time ))

if [ $status -ne 0 ]; then
  add_test_result "HPA-01" "Retrieve HPA list" "FAIL" "${duration}" "Failed to retrieve HPAs from namespace ${NAMESPACE}." ""
  finalize_test_suite
else
  add_test_result "HPA-01" "Retrieve HPA list" "PASS" "${duration}" "Successfully retrieved HPAs." ""
fi

# Check for <unknown> targets in HPA
hpa_count=$(echo "${hpa_list}" | jq '.items | length')

if [ "${hpa_count}" -eq 0 ]; then
  add_test_result "HPA-02" "Evaluate HPA targets" "FAIL" "0" "No HPAs found in namespace ${NAMESPACE}." ""
else
  unknown_count=0
  for i in $(seq 0 $((hpa_count - 1))); do
    hpa_name=$(echo "${hpa_list}" | jq -r ".items[$i].metadata.name")
    
    # Check if there are any targets in the list that do not have a current value or current utilization
    # Depending on metrics server readiness, it could be <unknown>. In JSON this often translates to missing 'current' block.
    # We will check the current metrics array.
    targets_status=$(k get hpa "${hpa_name}" -n "${NAMESPACE}" --no-headers | awk '{print $3}')
    
    if [[ "${targets_status}" == *"<unknown>"* ]]; then
      unknown_count=$((unknown_count + 1))
      add_test_result "HPA-02-${hpa_name}" "Evaluate HPA targets for ${hpa_name}" "FAIL" "0" "HPA target metric is <unknown>. Metrics Server might not be collecting data for this pod." "${targets_status}"
    else
      add_test_result "HPA-02-${hpa_name}" "Evaluate HPA targets for ${hpa_name}" "PASS" "0" "HPA target metric is active." "${targets_status}"
    fi
  done
  
  if [ "${unknown_count}" -eq 0 ]; then
     add_test_result "HPA-03" "Overall HPA metrics status" "PASS" "0" "All ${hpa_count} HPAs have active metric targets." ""
  else
     add_test_result "HPA-03" "Overall HPA metrics status" "FAIL" "0" "${unknown_count} HPAs have <unknown> target metrics." ""
  fi
fi

finalize_test_suite
