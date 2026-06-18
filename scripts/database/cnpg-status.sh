#!/usr/bin/env bash
# cnpg-status.sh — Check CloudNativePG cluster status
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
header(){ printf "\n${BLUE}═══ %s ═══${NC}\n" "$*"; }

NAMESPACE="${NAMESPACE:-securerag-database}"
CLUSTER="${CLUSTER:-securerag-db}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  CNPG CLUSTER STATUS — ${CLUSTER}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# 1. Cluster overview
header "Cluster Overview"
if kubectl get clusters -n "${NAMESPACE}" "${CLUSTER}" -o wide 2>/dev/null; then
  CLUSTER_JSON=$(kubectl get clusters -n "${NAMESPACE}" "${CLUSTER}" -o json 2>/dev/null || echo "{}")
  INSTANCES=$(echo "${CLUSTER_JSON}" | jq -r '.status.instances // "?"' 2>/dev/null)
  READY_INSTANCES=$(echo "${CLUSTER_JSON}" | jq -r '.status.readyInstances // "?"' 2>/dev/null)
  STATUS=$(echo "${CLUSTER_JSON}" | jq -r '.status.phase // "?"' 2>/dev/null)
  echo "  Desired instances: ${INSTANCES}"
  echo "  Ready instances:   ${READY_INSTANCES}"
  echo "  Phase:             ${STATUS}"
else
  warn "Cluster ${CLUSTER} not found"
fi

# 2. Pod status
header "Pod Status"
PODS=$(kubectl get pods -n "${NAMESPACE}" -l cnpg.io/cluster="${CLUSTER}" -o wide 2>/dev/null || echo "No pods found")
echo "${PODS}"

echo ""
# Show role labels per pod
for pod in $(kubectl get pods -n "${NAMESPACE}" -l cnpg.io/cluster="${CLUSTER}" -o name 2>/dev/null); do
  ROLE=$(kubectl get "${pod}" -n "${NAMESPACE}" -o jsonpath='{.metadata.labels.cnpg\.io/instanceRole}' 2>/dev/null || echo "unknown")
  PHASE=$(kubectl get "${pod}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
  echo "  ${pod#pods/} → role: ${ROLE}, phase: ${PHASE}"
done

# 3. Services
header "Services"
kubectl get services -n "${NAMESPACE}" -l cnpg.io/cluster="${CLUSTER}" 2>/dev/null || echo "No services found"

# 4. Replication status
header "Replication Status"
PRIMARY=$(kubectl get pods -n "${NAMESPACE}" -l cnpg.io/cluster="${CLUSTER}",cnpg.io/instanceRole=primary -o name 2>/dev/null | head -1)
if [ -n "${PRIMARY}" ]; then
  echo "  Primary: ${PRIMARY#pods/}"
  kubectl exec -n "${NAMESPACE}" "${PRIMARY}" -c postgres -- psql -U securerag -t -A -c "
    SELECT pid, usename, application_name, client_addr, state, sync_state,
           pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
    FROM pg_stat_replication;
  " 2>/dev/null || warn "Cannot query replication status (may need auth)"
else
  warn "No primary pod found"
fi

# 5. Backup status
header "Backup Status"
kubectl get backups -n "${NAMESPACE}" -o wide 2>/dev/null || echo "No backups found"

echo ""
LATEST_BACKUP=$(kubectl get backups -n "${NAMESPACE}" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")
if [ -n "${LATEST_BACKUP}" ]; then
  BACKUP_STATUS=$(kubectl get backup "${LATEST_BACKUP}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
  BACKUP_TIME=$(kubectl get backup "${LATEST_BACKUP}" -n "${NAMESPACE}" -o jsonpath='{.status.startedAt}' 2>/dev/null || echo "unknown")
  echo "  Latest backup: ${LATEST_BACKUP}"
  echo "  Status:        ${BACKUP_STATUS}"
  echo "  Started at:    ${BACKUP_TIME}"
fi

# 6. Scheduled backups
header "Scheduled Backups"
kubectl get scheduledbackups -n "${NAMESPACE}" -o wide 2>/dev/null || echo "No scheduled backups"

# 7. PVC status
header "PVC Status"
kubectl get pvc -n "${NAMESPACE}" -l cnpg.io/cluster="${CLUSTER}" 2>/dev/null || echo "No PVCs found"

# 8. Metrics endpoint check
header "Metrics Endpoint"
for pod in $(kubectl get pods -n "${NAMESPACE}" -l cnpg.io/cluster="${CLUSTER}",cnpg.io/instanceRole=primary -o name 2>/dev/null | head -1); do
  POD_NAME="${pod#pods/}"
  if kubectl get "${pod}" -n "${NAMESPACE}" -o jsonpath='{.spec.containers[*].ports[?(@.containerPort==9187)].name}' 2>/dev/null | grep -q metrics; then
    echo "  ${POD_NAME}: metrics port 9187 available"
  else
    warn "  ${POD_NAME}: no metrics port found"
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Status check complete"
echo "═══════════════════════════════════════════════════════════════"
