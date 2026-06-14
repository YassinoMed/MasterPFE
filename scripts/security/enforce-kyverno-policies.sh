#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Enforcing Kyverno ClusterPolicies..."

POLICIES=$(kubectl get clusterpolicies -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POLICIES" ]; then
    echo "[WARN] No Kyverno ClusterPolicies found in the cluster."
    exit 0
fi

for policy in $POLICIES; do
    echo "Enforcing policy: $policy"
    kubectl patch clusterpolicy "$policy" --type='json' -p='[{"op": "replace", "path": "/spec/validationFailureAction", "value": "Enforce"}]'
done

echo "[INFO] Verification of policy status:"
kubectl get clusterpolicies -o custom-columns=NAME:.metadata.name,ACTION:.spec.validationFailureAction

echo "[OK] All Kyverno policies are now in Enforce mode."
