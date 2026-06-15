#!/usr/bin/env bash
# security/tests/02-kyverno-policies-test.sh
# Tests Kyverno PolicyReports to ensure 100% compliance (0 FAIL results).

set -euo pipefail

# Source the framework
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-framework.sh"

init_test_suite "kyverno-compliance-validation"

# 1. Check if Kyverno is deployed and reachable
echo "[INFO] Checking Kyverno admission controller availability..."
start_time=$(date +%s)
set +e
k get deployment -n kyverno kyverno-admission-controller >/dev/null 2>&1
status=$?
set -e
duration=$(( $(date +%s) - start_time ))

if [ $status -eq 0 ]; then
  add_test_result "KYV-00" "Kyverno Admission Controller is running" "PASS" "${duration}" "Deployment kyverno-admission-controller found." ""
else
  add_test_result "KYV-00" "Kyverno Admission Controller is running" "FAIL" "${duration}" "Kyverno deployment not found in kyverno namespace." ""
  finalize_test_suite
fi

# 2. Check PolicyReports (namespace-scoped)
echo "[INFO] Analyzing PolicyReports..."
start_time=$(date +%s)
set +e
polr_data=$(k get polr -A -o json)
status=$?
set -e
duration=$(( $(date +%s) - start_time ))

if [ $status -ne 0 ]; then
  add_test_result "KYV-01" "PolicyReports retrieval" "FAIL" "${duration}" "Failed to retrieve PolicyReports." ""
else
  add_test_result "KYV-01" "PolicyReports retrieval" "PASS" "${duration}" "Successfully retrieved PolicyReports." ""
  
  # Parse failures using jq
  fail_count=$(echo "${polr_data}" | jq -r '.items[] | .summary.fail' | awk '{sum+=$1} END {print sum+0}')
  pass_count=$(echo "${polr_data}" | jq -r '.items[] | .summary.pass' | awk '{sum+=$1} END {print sum+0}')
  
  if [ "${fail_count}" -eq 0 ]; then
    add_test_result "KYV-02" "Zero failed policies in PolicyReports" "PASS" "0" "Found ${pass_count} passing checks and 0 failing checks." ""
  else
    failed_details=$(echo "${polr_data}" | jq -c '.items[] | select(.summary.fail > 0) | {namespace: .metadata.namespace, name: .metadata.name, fails: .summary.fail}')
    add_test_result "KYV-02" "Zero failed policies in PolicyReports" "FAIL" "0" "Found ${fail_count} failing checks across resources." "${failed_details}"
  fi
fi

# 3. Check ClusterPolicyReports (cluster-scoped)
echo "[INFO] Analyzing ClusterPolicyReports..."
start_time=$(date +%s)
set +e
cpolr_data=$(k get cpolr -A -o json)
status=$?
set -e
duration=$(( $(date +%s) - start_time ))

if [ $status -ne 0 ]; then
  # It's possible there are no ClusterPolicyReports, we shouldn't necessarily fail but warn if error.
  # Let's just check if it returns valid JSON. If not, maybe CRD isn't there.
  add_test_result "KYV-03" "ClusterPolicyReports retrieval" "FAIL" "${duration}" "Failed to retrieve ClusterPolicyReports." ""
else
  add_test_result "KYV-03" "ClusterPolicyReports retrieval" "PASS" "${duration}" "Successfully retrieved ClusterPolicyReports." ""
  
  cfail_count=$(echo "${cpolr_data}" | jq -r '.items[] | .summary.fail' | awk '{sum+=$1} END {print sum+0}')
  cpass_count=$(echo "${cpolr_data}" | jq -r '.items[] | .summary.pass' | awk '{sum+=$1} END {print sum+0}')
  
  if [ "${cfail_count}" -eq 0 ]; then
    add_test_result "KYV-04" "Zero failed policies in ClusterPolicyReports" "PASS" "0" "Found ${cpass_count} passing checks and 0 failing checks." ""
  else
    cfailed_details=$(echo "${cpolr_data}" | jq -c '.items[] | select(.summary.fail > 0) | {name: .metadata.name, fails: .summary.fail}')
    add_test_result "KYV-04" "Zero failed policies in ClusterPolicyReports" "FAIL" "0" "Found ${cfail_count} failing checks across cluster resources." "${cfailed_details}"
  fi
fi

finalize_test_suite
