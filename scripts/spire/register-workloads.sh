#!/usr/bin/env bash
# File: scripts/spire/register-workloads.sh
# Description: Registers SPIRE workload entries for all SecureRAG Hub services.
# Usage: bash scripts/spire/register-workloads.sh
# Prerequisites: spire-server must be running in the spire namespace.

set -euo pipefail

NAMESPACE="spire"
SERVER_LABEL="app.kubernetes.io/name=spire-server"
SERVICES=("portal-web" "auth-users" "chatbot-manager" "conversation-service" "audit-security-service")
TRUST_DOMAIN="securerag-hub.securerag.dev"
SERVICE_NAMESPACE="securerag-hub"
TTL=3600

echo ">> Locating SPIRE server pod..."
SPIRE_SERVER_POD=$(kubectl get pod -n "$NAMESPACE" -l "$SERVER_LABEL" -o jsonpath='{.items[0].metadata.name}')
if [ -z "$SPIRE_SERVER_POD" ]; then
  echo "[ERROR] Could not find spire-server pod in namespace $NAMESPACE."
  exit 1
fi
echo "   Using pod: $SPIRE_SERVER_POD"

echo ""
echo ">> Fetching attested agent node list..."
kubectl exec -n "$NAMESPACE" "$SPIRE_SERVER_POD" -- /opt/spire/bin/spire-server agent list

echo ""
echo ">> Registering workload entries..."

for svc in "${SERVICES[@]}"; do
  SPIFFE_ID="spiffe://${TRUST_DOMAIN}/${svc}"
  SELECTOR="k8s:sa:${SERVICE_NAMESPACE}:${svc}"

  echo "   Creating entry for $svc..."
  echo "     SPIFFE ID: $SPIFFE_ID"
  echo "     Selector:  $SELECTOR"

  kubectl exec -n "$NAMESPACE" "$SPIRE_SERVER_POD" -- /opt/spire/bin/spire-server entry create \
    -spiffeID "$SPIFFE_ID" \
    -parentID "spiffe://${TRUST_DOMAIN}/spire/server" \
    -selector "$SELECTOR" \
    -ttl "$TTL" \
    2>/dev/null || echo "     [WARN] Entry for $svc may already exist (idempotent)."
done

echo ""
echo ">> Validating registered entries..."
kubectl exec -n "$NAMESPACE" "$SPIRE_SERVER_POD" -- /opt/spire/bin/spire-server entry show

echo ""
echo ">> Workload registration complete."
echo "   Registered services: ${SERVICES[*]}"
