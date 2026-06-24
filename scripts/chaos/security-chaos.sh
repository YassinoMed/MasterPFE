#!/bin/bash
set -euo pipefail

NAMESPACE="securerag-hub"
POD_NAME="chaos-security-dummy"

echo "[INFO] Deploying a vulnerable dummy pod for security chaos testing..."
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  labels:
    app: security-chaos
spec:
  containers:
  - name: dummy
    image: ubuntu:latest
    command: ["/bin/sleep", "3600"]
    securityContext:
      privileged: true # intentionally vulnerable
EOF

echo "[INFO] Waiting for the dummy pod to become ready..."
kubectl wait --for=condition=ready pod $POD_NAME -n $NAMESPACE --timeout=60s

echo "[INFO] Commencing Security Attacks..."
echo "------------------------------------------------------"

echo "[ATTACK 1] Executing interactive shell in container (Triggers: SecureRAG Shell in Container)"
# Running a shell command in the background to simulate an attacker.
# We expect Falco Talon to kill the pod immediately.
kubectl exec $POD_NAME -n $NAMESPACE -- /bin/bash -c "echo 'I am an attacker inside the pod!'; exit 0" || true

sleep 2

echo "[INFO] Checking pod status..."
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "Deleted")
echo "Pod Status: $POD_STATUS"

if [ "$POD_STATUS" == "Deleted" ] || [ -z "$POD_STATUS" ]; then
    echo "✅ [SUCCESS] Falco Talon successfully terminated the compromised pod."
else
    echo "❌ [FAILED] The pod is still running. Falco Talon automated response failed."
    # Cleanup just in case
    kubectl delete pod $POD_NAME -n $NAMESPACE --force --grace-period=0 || true
fi

echo "------------------------------------------------------"
echo "[INFO] Security Chaos Testing Complete. Check Slack and Loki for audit trails."
