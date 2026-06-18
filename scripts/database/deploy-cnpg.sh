#!/usr/bin/env bash
# deploy-cnpg.sh — Deploy CloudNativePG operator + cluster
# SecureRAG Hub — PostgreSQL HA Phase 3
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "${BLUE}[STEP]${NC}  %s\n" "$*"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  CLOUDNATIVEPG — POSTGRESQL HA DEPLOYMENT"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Config
CNPG_VERSION="${CNPG_VERSION:-1.25.0}"
CNPG_NAMESPACE="securerag-database"
KUSTOMIZE_DIR="infra/k8s/database/cloudnativepg"
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Phase 1: Create namespace
step "Phase 1/6: Creating namespace..."
kubectl create namespace "${CNPG_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "${CNPG_NAMESPACE}" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite
info "Namespace ${CNPG_NAMESPACE} ready"

# Phase 2: Deploy CloudNativePG CRDs
step "Phase 2/6: Deploying CloudNativePG CRDs..."
kubectl apply -f "https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-${CNPG_VERSION%.*}/releases/cnpg-${CNPG_VERSION}.yaml" \
  --server-side
info "CloudNativePG CRDs deployed"

# Phase 3: Wait for CRDs to be established
step "Phase 3/6: Waiting for CRDs to be established..."
for crd in clusters.postgresql.cnpg.io backups.postgresql.cnpg.io scheduledbackups.postgresql.cnpg.io; do
  kubectl wait --for=condition=Established "crd/${crd}" --timeout=120s
done
info "CRDs established"

# Phase 4: Deploy operator and cluster resources via kustomize
step "Phase 4/6: Deploying CNPG operator and cluster resources..."
kubectl apply -k "${SCRIPT_DIR}/${KUSTOMIZE_DIR}" --server-side
info "Operator and cluster resources applied"

# Phase 5: Wait for cluster readiness
step "Phase 5/6: Waiting for PostgreSQL cluster to be ready..."
kubectl wait --for=condition=Ready clusters.postgresql.cnpg.io securerag-db \
  -n "${CNPG_NAMESPACE}" --timeout=300s || \
  warn "Cluster not ready yet — check with: kubectl get clusters -n ${CNPG_NAMESPACE}"

info "Waiting for all pods to be Ready..."
kubectl wait --for=condition=Ready pods \
  -n "${CNPG_NAMESPACE}" \
  -l cnpg.io/cluster=securerag-db \
  --timeout=300s || \
  warn "Some pods not ready yet"

# Phase 6: Verify deployment
step "Phase 6/6: Verifying deployment..."
echo ""
info "CNPG Operator:"
kubectl get deployment cnpg-operator -n "${CNPG_NAMESPACE}" -o wide
echo ""
info "PostgreSQL Cluster:"
kubectl get clusters -n "${CNPG_NAMESPACE}" -o wide
echo ""
info "Pods:"
kubectl get pods -n "${CNPG_NAMESPACE}" -l cnpg.io/cluster=securerag-db -o wide
echo ""
info "Services:"
kubectl get services -n "${CNPG_NAMESPACE}" -l cnpg.io/cluster=securerag-db
echo ""
info "Backups:"
kubectl get backups -n "${CNPG_NAMESPACE}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ CLOUDNATIVEPG DEPLOYMENT COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  RW endpoint: securerag-db-rw.${CNPG_NAMESPACE}:5432"
echo "  RO endpoint: securerag-db-ro.${CNPG_NAMESPACE}:5432"
echo ""
echo "  To connect:"
echo "    kubectl run psql-client --rm -it --image=postgres:16-alpine -- psql"
echo ""
echo "  To test failover:"
echo "    kubectl delete pod -n ${CNPG_NAMESPACE} -l cnpg.io/instanceRole=primary"
echo ""
echo "  View status:    scripts/database/cnpg-status.sh"
echo "═══════════════════════════════════════════════════════════════"
