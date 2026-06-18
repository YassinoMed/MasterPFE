#!/usr/bin/env bash
set -Eeuo pipefail

########################################
# SecureRAG Hub - Test Tetragon       #
# Triggers each policy and verifies   #
# that Tetragon events are captured.  #
########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="${TEST_NAMESPACE:-securerag-hub}"
TETRAGON_NS="${TETRAGON_NAMESPACE:-kube-system}"
RESULTS_DIR="${RESULTS_DIR:-${REPO_DIR}/artifacts/tetragon-tests}"

PASS=0
FAIL=0
SKIP=0
TESTS=()

log()    { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
info()   { printf '  [INFO] %s\n' "$*"; }
pass()   { printf '  [PASS] %s\n' "$*"; ((PASS++)); }
fail()   { printf '  [FAIL] %s\n' "$*"; ((FAIL++)); }
skip()   { printf '  [SKIP] %s\n' "$*"; ((SKIP++)); }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    fail "Required command not found: $1"
    return 1
  }
}

cleanup() {
  local pod="$1"
  local ns="${2:-default}"
  kubectl delete pod "${pod}" --namespace="${ns}" --ignore-not-found --timeout=10s 2>/dev/null || true
}

check_tetragon_running() {
  if ! kubectl get pods -n "${TETRAGON_NS}" -l app.kubernetes.io/name=tetragon 2>/dev/null | grep -q Running; then
    fail "Tetragon is not running. Skipping all tests."
    return 1
  fi
  return 0
}

check_policy_loaded() {
  local policy="$1"
  if kubectl get tracingpolicies "${policy}" &>/dev/null; then
    return 0
  fi
  return 1
}

wait_for_event() {
  local policy="$1"
  local timeout="${2:-10}"
  info "Waiting ${timeout}s for Tetragon event from '${policy}'..."
  sleep "${timeout}"
}

print_summary() {
  local total=$((PASS + FAIL + SKIP))
  printf '\n%s\n' "========================================"
  printf '  TEST RESULTS\n'
  printf '  Total: %d | PASS: %d | FAIL: %d | SKIP: %d\n' "${total}" "${PASS}" "${FAIL}" "${SKIP}"
  printf '%s\n' "========================================"
}

require_cmd kubectl

mkdir -p "${RESULTS_DIR}"

log "SecureRAG Hub - Tetragon Policy Test Suite"
log "==========================================="
log "Namespace:     ${NAMESPACE}"
log "Tetragon NS:   ${TETRAGON_NS}"
log "Results dir:   ${RESULTS_DIR}"
log ""

# ---- Prerequisite checks ----
if ! check_tetragon_running; then
  print_summary
  exit 1
fi

# ---- Test 1: kubectl exec detection ----
TESTS+=("securerag-detect-kubectl-exec")
if check_policy_loaded "securerag-detect-kubectl-exec"; then
  info "Test 1: Triggering kubectl exec detection"
  POD="kubectl-exec-test-$(date +%s)"
  kubectl run "${POD}" --image=nginx:alpine --restart=Never -n "${NAMESPACE}" -- sleep 60 2>/dev/null || true
  kubectl wait --for=condition=Ready pod/"${POD}" -n "${NAMESPACE}" --timeout=30s 2>/dev/null || true
  kubectl exec -n "${NAMESPACE}" "${POD}" -- ls /tmp 2>/dev/null || true
  wait_for_event "securerag-detect-kubectl-exec" 5
  cleanup "${POD}" "${NAMESPACE}"
  # Check tetragon logs for the event
  if kubectl logs -n "${TETRAGON_NS}" -l app.kubernetes.io/name=tetragon --tail=50 2>/dev/null | grep -qi "kubectl-exec\|T1569\|securerag-detect-kubectl-exec"; then
    pass "kubectl exec event detected in Tetragon logs"
  else
    fail "kubectl exec event not found in Tetragon logs"
  fi
else
  skip "Policy 'securerag-detect-kubectl-exec' not loaded"
fi

# ---- Test 2: Shell detection ----
TESTS+=("securerag-detect-shell")
if check_policy_loaded "securerag-detect-shell"; then
  info "Test 2: Triggering shell detection"
  POD="shell-test-$(date +%s)"
  kubectl run "${POD}" --image=nginx:alpine --restart=Never -n "${NAMESPACE}" -- sleep 60 2>/dev/null || true
  kubectl wait --for=condition=Ready pod/"${POD}" -n "${NAMESPACE}" --timeout=30s 2>/dev/null || true
  kubectl exec -n "${NAMESPACE}" "${POD}" -- /bin/sh -c "ls" 2>/dev/null || true
  wait_for_event "securerag-detect-shell" 5
  cleanup "${POD}" "${NAMESPACE}"
  if kubectl logs -n "${TETRAGON_NS}" -l app.kubernetes.io/name=tetragon --tail=50 2>/dev/null | grep -qi "shell\|T1059\|securerag-detect-shell"; then
    pass "Shell execution event detected in Tetragon logs"
  else
    fail "Shell execution event not found in Tetragon logs"
  fi
else
  skip "Policy 'securerag-detect-shell' not loaded"
fi

# ---- Test 3: Network tools detection ----
TESTS+=("securerag-detect-network-tools")
if check_policy_loaded "securerag-detect-network-tools"; then
  info "Test 3: Triggering network tool detection"
  POD="network-test-$(date +%s)"
  kubectl run "${POD}" --image=nginx:alpine --restart=Never -n "${NAMESPACE}" -- sleep 60 2>/dev/null || true
  kubectl wait --for=condition=Ready pod/"${POD}" -n "${NAMESPACE}" --timeout=30s 2>/dev/null || true
  kubectl exec -n "${NAMESPACE}" "${POD}" -- which curl 2>/dev/null || true
  kubectl exec -n "${NAMESPACE}" "${POD}" -- which wget 2>/dev/null || true
  wait_for_event "securerag-detect-network-tools" 5
  cleanup "${POD}" "${NAMESPACE}"
  if kubectl logs -n "${TETRAGON_NS}" -l app.kubernetes.io/name=tetragon --tail=50 2>/dev/null | grep -qi "network\|T1105\|securerag-detect-network-tools"; then
    pass "Network tools event detected in Tetragon logs"
  else
    fail "Network tools event not found in Tetragon logs"
  fi
else
  skip "Policy 'securerag-detect-network-tools' not loaded"
fi

# ---- Test 4: Crypto miner detection ----
TESTS+=("securerag-detect-crypto-miners")
if check_policy_loaded "securerag-detect-crypto-miners"; then
  info "Test 4: Triggering crypto miner detection (simulated binary name)"
  POD="crypto-test-$(date +%s)"
  kubectl run "${POD}" --image=nginx:alpine --restart=Never -n "${NAMESPACE}" -- sleep 60 2>/dev/null || true
  kubectl wait --for=condition=Ready pod/"${POD}" -n "${NAMESPACE}" --timeout=30s 2>/dev/null || true
  kubectl exec -n "${NAMESPACE}" "${POD}" -- sh -c "echo '#!/bin/sh' > /tmp/xmrig && chmod +x /tmp/xmrig && /tmp/xmrig" 2>/dev/null || true
  wait_for_event "securerag-detect-crypto-miners" 5
  cleanup "${POD}" "${NAMESPACE}"
  if kubectl logs -n "${TETRAGON_NS}" -l app.kubernetes.io/name=tetragon --tail=50 2>/dev/null | grep -qi "crypto\|T1496\|securerag-detect-crypto-miners"; then
    pass "Crypto miner event detected in Tetragon logs"
  else
    fail "Crypto miner event not found in Tetragon logs"
  fi
else
  skip "Policy 'securerag-detect-crypto-miners' not loaded"
fi

# ---- Test 5: Privilege escalation detection ----
TESTS+=("securerag-detect-privilege-escalation")
if check_policy_loaded "securerag-detect-privilege-escalation"; then
  info "Test 5: Triggering privilege escalation detection"
  POD="priv-test-$(date +%s)"
  kubectl run "${POD}" --image=nginx:alpine --restart=Never -n "${NAMESPACE}" -- sleep 60 2>/dev/null || true
  kubectl wait --for=condition=Ready pod/"${POD}" -n "${NAMESPACE}" --timeout=30s 2>/dev/null || true
  kubectl exec -n "${NAMESPACE}" "${POD}" -- chmod 777 /tmp 2>/dev/null || true
  kubectl exec -n "${NAMESPACE}" "${POD}" -- chown root:root /tmp 2>/dev/null || true
  wait_for_event "securerag-detect-privilege-escalation" 5
  cleanup "${POD}" "${NAMESPACE}"
  if kubectl logs -n "${TETRAGON_NS}" -l app.kubernetes.io/name=tetragon --tail=50 2>/dev/null | grep -qi "privilege\|T1611\|securerag-detect-privilege-escalation"; then
    pass "Privilege escalation event detected in Tetragon logs"
  else
    fail "Privilege escalation event not found in Tetragon logs"
  fi
else
  skip "Policy 'securerag-detect-privilege-escalation' not loaded"
fi

# ---- Summary ----
print_summary

# Write results to file
cat > "${RESULTS_DIR}/tetragon-test-results.txt" <<EOF
Tetragon Policy Test Results
Date: $(date)
Namespace: ${NAMESPACE}
Total: $((PASS + FAIL + SKIP)) | PASS: ${PASS} | FAIL: ${FAIL} | SKIP: ${SKIP}
EOF

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
exit 0
