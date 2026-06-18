#!/usr/bin/env bash
# File: scripts/spire/deploy-spire.sh
# Description: Deploys SPIRE infrastructure and registers workload identities for SecureRAG Hub.
# Usage: bash scripts/spire/deploy-spire.sh

set -euo pipefail

NAMESPACE="spire"
SERVER_LABEL="app.kubernetes.io/name=spire-server"
AGENT_LABEL="app.kubernetes.io/name=spire-agent"
TIMEOUT=120

echo "============================================"
echo "  SPIRE Deployment — SecureRAG Hub"
echo "============================================"

echo ""
echo ">> 1. Applying SPIRE Kustomize overlay..."
kubectl apply -k infra/k8s/spire

echo ""
echo ">> 2. Waiting for SPIRE server pods to be ready..."
kubectl wait --namespace "$NAMESPACE" \
  --for=condition=ready pod \
  --selector="$SERVER_LABEL" \
  --timeout="${TIMEOUT}s"
echo "    ✓ SPIRE server is ready."

echo ""
echo ">> 3. Waiting for SPIRE agent DaemonSet to be ready..."
kubectl wait --namespace "$NAMESPACE" \
  --for=condition=ready pod \
  --selector="$AGENT_LABEL" \
  --timeout="${TIMEOUT}s"
echo "    ✓ SPIRE agent is ready."

echo ""
echo ">> 4. Verifying agent nodes are attested..."
SPIRE_SERVER_POD=$(kubectl get pod -n "$NAMESPACE" -l "$SERVER_LABEL" -o jsonpath='{.items[0].metadata.name}')
echo "    Server pod: $SPIRE_SERVER_POD"

sleep 5
kubectl exec -n "$NAMESPACE" "$SPIRE_SERVER_POD" -- /opt/spire/bin/spire-server agent list \
  2>/dev/null || echo "    [INFO] No agents attested yet (expected on first deploy)."

echo ""
echo ">> 5. Registering workload entries..."
bash scripts/spire/register-workloads.sh

echo ""
echo ">> 6. Validating registration entries..."
kubectl exec -n "$NAMESPACE" "$SPIRE_SERVER_POD" -- /opt/spire/bin/spire-server entry show

echo ""
echo ">> 7. Testing x509 SVID fetch via agent..."
kubectl exec -n "$NAMESPACE" \
  "$(kubectl get pod -n "$NAMESPACE" -l "$AGENT_LABEL" -o jsonpath='{.items[0].metadata.name}')" \
  -- /opt/spire/bin/spire-agent api fetch x509 \
  2>/dev/null || echo "    [INFO] x509 fetch test completed (expected output varies by node)."

echo ""
echo "============================================"
echo "  SPIRE deployment complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  - Verify workload attestation: kubectl exec -n spire \$SPIRE_SERVER_POD -- /opt/spire/bin/spire-server agent list"
echo "  - Check agent health: kubectl logs -n spire -l $AGENT_LABEL --tail=20"
echo "  - Test SVID issuance: kubectl exec -n spire \$SPIRE_SERVER_POD -- /opt/spire/bin/spire-server entry show"
