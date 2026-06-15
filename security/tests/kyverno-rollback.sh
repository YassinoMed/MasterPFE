#!/usr/bin/env bash
# security/tests/kyverno-rollback.sh
# Emergency rollback script to revert Kyverno policies to Audit mode and diagnose issues.

set -euo pipefail

echo "=== EMERGENCY KYVERNO ROLLBACK & TROUBLESHOOTING ==="

# 1. Rollback all ClusterPolicies to Audit mode
echo "[INFO] Scanning for Kyverno ClusterPolicies in the cluster..."
POLICIES=$(kubectl get clusterpolicies -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POLICIES" ]; then
    echo "[WARN] No Kyverno ClusterPolicies found in the cluster to rollback."
else
    for policy in $POLICIES; do
        echo "Rolling back policy: $policy to Audit mode..."
        kubectl patch clusterpolicy "$policy" --type='json' -p='[{"op": "replace", "path": "/spec/validationFailureAction", "value": "Audit"}]' 2>/dev/null || \
        echo "[WARN] Failed to patch policy $policy. It might have been deleted."
    done
    echo "[OK] All Kyverno ClusterPolicies have been reverted to Audit mode successfully."
fi

# 2. Re-verify policies
echo "[INFO] Current Kyverno ClusterPolicies status:"
kubectl get clusterpolicies -o custom-columns=NAME:.metadata.name,ACTION:.spec.validationFailureAction

# 3. How to identify which pod caused a block
echo ""
echo "=== TROUBLESHOOTING GUIDE ==="
echo "1. To check the latest replica set creation failures (events):"
echo "   kubectl get events -A --field-selector reason=FailedCreate --sort-by='.metadata.creationTimestamp' | tail -n 5"
echo ""
echo "2. To check Kyverno admission controller log violations:"
echo "   kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller --tail=50 | grep -E 'validation error|blocked'"
echo ""
echo "3. To check if a pod is pending due to admission webhook blocking:"
echo "   kubectl describe replicaset -n <namespace> <replicaset-name>"
echo ""
echo "=== TEMPORARY POLICY EXCEPTIONS ==="
echo "To temporarily exempt a resource without switching back to Audit mode, apply a PolicyException:"
echo "  1. Edit k8s/kyverno-policies/exceptions/policy-exception-template.yaml"
echo "  2. Deploy it: kubectl apply -f k8s/kyverno-policies/exceptions/policy-exception-template.yaml"
echo ""
