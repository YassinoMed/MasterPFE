#!/usr/bin/env bash
# deploy-vault-and-eso.sh — Deploy Vault + External Secrets Operator
# SecureRAG Hub — Enterprise Secrets Management
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VAULT + EXTERNAL SECRETS OPERATOR — DEPLOYMENT"
echo "═══════════════════════════════════════════════════════════════"

# Phase 1: Deploy Vault
info "Phase 1/6: Deploying HashiCorp Vault..."
kubectl apply -k infra/k8s/vault/
kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=180s || {
  error "Vault pod not ready after 3 minutes"
  kubectl describe pod vault-0 -n vault
  exit 1
}
info "Vault deployed successfully"

# Phase 2: Initialize Vault
info "Phase 2/6: Initializing Vault..."
bash scripts/secrets/initialize-vault.sh --auto-unseal

# Phase 3: Install External Secrets Operator
info "Phase 3/6: Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --values infra/helm/external-secrets/values-production.yaml \
  --wait --timeout 5m

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=external-secrets \
  -n external-secrets --timeout=120s || {
  error "External Secrets Operator not ready"
  exit 1
}
info "External Secrets Operator installed"

# Phase 4: Configure ClusterSecretStore
info "Phase 4/6: Configuring ClusterSecretStore..."
kubectl apply -f infra/k8s/secrets/eso-cluster-secret-store.prod.yaml
info "ClusterSecretStore 'vault-backend' created"

# Phase 5: Create ExternalSecrets
info "Phase 5/6: Creating ExternalSecrets..."
for es in infra/k8s/secrets/*external-secret*.yaml; do
  kubectl apply -f "${es}"
  info "  Applied: ${es}"
done

# Phase 6: Deploy secret rotation CronJob
info "Phase 6/6: Deploying secret rotation CronJob..."
kubectl apply -f infra/k8s/jobs/secret-rotation-cronjob.yaml
info "Secret rotation CronJob deployed"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ VAULT + ESO DEPLOYMENT COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Vault UI: kubectl port-forward -n vault vault-0 8200:8200"
echo "  Verify: kubectl get externalsecret -A"
echo "  Verify: kubectl get secret -n securerag-hub db-credentials"
echo ""

# Verify
info "Verifying deployment..."
kubectl get externalsecret -A 2>/dev/null | head -10 || warn "No ExternalSecrets found"
kubectl get pods -n vault 2>/dev/null || warn "Vault not found"
kubectl get pods -n external-secrets 2>/dev/null || warn "ESO not found"
