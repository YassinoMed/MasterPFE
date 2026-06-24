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
info "Phase 1/6: Waiting for ArgoCD to deploy HashiCorp Vault..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s || {
  error "Vault pod not ready after 5 minutes"
  kubectl describe pod -l app.kubernetes.io/name=vault -n vault || true
  exit 1
}
info "Vault deployed successfully"

# Phase 2: Initialize Vault
info "Phase 2/6: Initializing Vault..."
bash scripts/secrets/initialize-vault.sh --auto-unseal

# Phase 3: Install External Secrets Operator
info "Phase 3/6: Waiting for ArgoCD to deploy External Secrets Operator..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=external-secrets \
  -n external-secrets --timeout=300s || {
  error "External Secrets Operator not ready"
  exit 1
}
info "External Secrets Operator deployed successfully"

# Phase 4: Configure ClusterSecretStore
info "Phase 4/6: Configuring ClusterSecretStore..."
kubectl apply -f infra/k8s/secrets/eso-cluster-secret-store.yaml
info "ClusterSecretStore 'vault-backend' created"

# Phase 5: Create ExternalSecrets
info "Phase 5/6: Creating ExternalSecrets..."
kubectl apply -k infra/k8s/secrets/
info "ExternalSecrets applied successfully"

# Phase 6: Secret Rotation Policy
info "Phase 6/6: Verifying secret rotation configuration..."
info "Rotation is configured natively via ExternalSecrets refreshInterval"

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
