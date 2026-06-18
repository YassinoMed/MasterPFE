#!/usr/bin/env bash
# deploy-opa-gatekeeper.sh — Deploy OPA Gatekeeper with SecureRAG Hub policies
# SecureRAG Hub — Policy as Code
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" "$*" >&2; }
step()  { printf "${BLUE}[STEP]${NC}  %s\n" "$*"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  OPA GATEKEEPER — DEPLOYMENT"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Phase 1: Create namespace
step "Phase 1/4: Creating namespace..."
kubectl create namespace gatekeeper-system --dry-run=client -o yaml | kubectl apply -f -
info "Namespace ready"

# Phase 2: Deploy Gatekeeper
step "Phase 2/4: Deploying Gatekeeper..."
kubectl apply -k infra/k8s/opa-gatekeeper/
info "Gatekeeper deployed"

# Phase 3: Wait for readiness
step "Phase 3/4: Waiting for Gatekeeper to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=gatekeeper -n gatekeeper-system --timeout=180s || {
  error "Gatekeeper pods not ready"
  kubectl get pods -n gatekeeper-system
  exit 1
}
info "Gatekeeper is ready"

# Phase 4: Verify constraints
step "Phase 4/4: Verifying constraints..."
kubectl get constrainttemplates
echo ""
kubectl get constraints
echo ""

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ OPA GATEKEEPER DEPLOYMENT COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Verify with:"
echo "    kubectl get constrainttemplates"
echo "    kubectl get constraints"
echo "    kubectl describe constraint disallow-privileged-containers"
echo ""
echo "  Test a violation:"
echo "    kubectl run test-privileged --image=nginx --privileged --dry-run=client -o yaml | kubectl apply -f -"
echo "    # Should be rejected by Gatekeeper"
echo ""