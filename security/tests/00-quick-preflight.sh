#!/usr/bin/env bash
# /root/MasterPFE/security/tests/00-quick-preflight.sh
# ── SCRIPT 00 : Pré-vérification rapide (< 30s total) ──────────────

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/test-framework.sh"

init_test_suite "quick-preflight"

cleanup() {
  finalize_test_suite
}
trap cleanup EXIT

echo "Running Preflight checks..."

# T00-01: kubectl available and connected
start=$(date +%s)
if evidence=$(kubectl --context="${KUBE_CONTEXT}" cluster-info 2>&1); then
  duration=$(( $(date +%s) - start ))
  add_test_result "T00-01" "kubectl connected to kind-securerag-cluster" "PASS" "$duration" "Connected successfully" "$evidence"
else
  duration=$(( $(date +%s) - start ))
  add_test_result "T00-01" "kubectl connected to kind-securerag-cluster" "FAIL" "$duration" "Could not connect" "$evidence"
fi

# T00-02: Namespace securerag-hub en état Active
start=$(date +%s)
if evidence=$(kubectl --context="${KUBE_CONTEXT}" get ns securerag-hub -o jsonpath='{.status.phase}' 2>&1) && [ "$evidence" = "Active" ]; then
  duration=$(( $(date +%s) - start ))
  add_test_result "T00-02" "Namespace securerag-hub is Active" "PASS" "$duration" "Namespace is Active" "$evidence"
else
  duration=$(( $(date +%s) - start ))
  evidence=$(kubectl --context="${KUBE_CONTEXT}" get ns securerag-hub 2>&1 || true)
  add_test_result "T00-02" "Namespace securerag-hub is Active" "FAIL" "$duration" "Namespace not Active or not found" "$evidence"
fi

# T00-03: Au moins 1 pod Running dans securerag-hub
start=$(date +%s)
if evidence=$(kubectl --context="${KUBE_CONTEXT}" get pods -n securerag-hub --field-selector=status.phase=Running 2>&1) && echo "$evidence" | grep -q "Running"; then
  duration=$(( $(date +%s) - start ))
  add_test_result "T00-03" "At least 1 pod Running in securerag-hub" "PASS" "$duration" "Running pod found" "$evidence"
else
  duration=$(( $(date +%s) - start ))
  add_test_result "T00-03" "At least 1 pod Running in securerag-hub" "FAIL" "$duration" "No running pods found" "$evidence"
fi

# T00-04: Vault en état unsealed
start=$(date +%s)
if evidence=$(kubectl --context="${KUBE_CONTEXT}" exec -n vault-system vault-0 -- vault status 2>&1) && echo "$evidence" | grep -q "Sealed.*false"; then
  duration=$(( $(date +%s) - start ))
  add_test_result "T00-04" "Vault is unsealed" "PASS" "$duration" "Vault is unsealed" "$evidence"
else
  duration=$(( $(date +%s) - start ))
  add_test_result "T00-04" "Vault is unsealed" "FAIL" "$duration" "Vault is sealed or inaccessible" "$evidence"
fi
