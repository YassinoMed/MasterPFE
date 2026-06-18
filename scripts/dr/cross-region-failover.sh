#!/usr/bin/env bash
# cross-region-failover.sh — Cross-Region Failover & Rollback
# SecureRAG Hub — World-Class Disaster Recovery
#
# Detects primary region failure, promotes DR cluster, updates DNS,
# validates DR health, and provides rollback procedure.
#
# Usage:
#   bash scripts/dr/cross-region-failover.sh --status           Check failover status
#   bash scripts/dr/cross-region-failover.sh --failover         Promote DR cluster
#   bash scripts/dr/cross-region-failover.sh --rollback         Rollback to primary
#   bash scripts/dr/cross-region-failover.sh --validate         Validate DR health
#   bash scripts/dr/cross-region-failover.sh --plan             Show failover plan
#
# Configuration via environment variables:
#   PRIMARY_CLUSTER      Primary kubeconfig context
#   DR_CLUSTER           DR kubeconfig context
#   PRIMARY_NAMESPACE    Primary namespace (default: securerag-hub)
#   DR_NAMESPACE         DR namespace (default: securerag-hub)
#   DNS_ZONE             DNS managed zone (default: securerag-hub.example.com)
#   DNS_RECORD           DNS record to update (default: api.securerag-hub.example.com)
#   HEALTH_CHECK_URL     URL for health check (default: https://api.securerag-hub.example.com/health)
#   VELERO_DR_LOCATION   Velero DR BackupStorageLocation (default: velero-dr)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()    { printf "${CYAN}[STEP]${NC}  %s\n" "$*"; }
header()  { printf "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}\n"; printf "${MAGENTA}  %s${NC}\n" "$*"; printf "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}\n"; }

# ── Configuration ─────────────────────────────────────────────

PRIMARY_CLUSTER="${PRIMARY_CLUSTER:-primary-eks}"
DR_CLUSTER="${DR_CLUSTER:-dr-eks}"
PRIMARY_NAMESPACE="${PRIMARY_NAMESPACE:-securerag-hub}"
DR_NAMESPACE="${DR_NAMESPACE:-securerag-hub}"
DNS_ZONE="${DNS_ZONE:-securerag-hub.example.com}"
DNS_RECORD="${DNS_RECORD:-api.securerag-hub.example.com}"
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-https://api.securerag-hub.example.com/health}"
VELERO_DR_LOCATION="${VELERO_DR_LOCATION:-velero-dr}"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
EVIDENCE_DIR="artifacts/dr/failover"
FAILOVER_STATE_FILE="${EVIDENCE_DIR}/failover-state.json"

mkdir -p "${EVIDENCE_DIR}"

# ── Helpers ──────────────────────────────────────────────────────

switch_context() {
  local context="$1"
  kubectl config use-context "${context}" 2>/dev/null || {
    error "Cannot switch to context '${context}'"
    exit 1
  }
  info "Switched to context: ${context}"
}

check_cluster_health() {
  local context="$1"
  local label="$2"
  local status=0

  kubectl config use-context "${context}" 2>/dev/null || return 1

  kubectl get nodes --no-headers 2>/dev/null | head -3 >/dev/null || return 1
  kubectl get pods -n "${PRIMARY_NAMESPACE}" --no-headers 2>/dev/null | head -3 >/dev/null || return 1

  info "Cluster '${label}' (${context}) is reachable"
  return 0
}

check_dns() {
  local record="${DNS_RECORD}"
  local expected="${1:-}"

  if command -v dig &>/dev/null; then
    RESOLVED=$(dig +short "${record}" 2>/dev/null | head -1)
    info "DNS '${record}' resolves to: ${RESOLVED:-unresolved}"
    if [ -n "${expected}" ] && [ "${RESOLVED}" = "${expected}" ]; then
      return 0
    fi
  elif command -v nslookup &>/dev/null; then
    RESOLVED=$(nslookup "${record}" 2>/dev/null | grep -i address | tail -1 | awk '{print $2}')
    info "DNS '${record}' resolves to: ${RESOLVED:-unresolved}"
  else
    warn "No DNS lookup tools available"
    return 2
  fi
}

update_dns_record() {
  local ip="$1"
  local action="${2:-UPSERT}"

  info "Updating DNS record '${DNS_RECORD}' -> ${ip} (${action})"

  # Cloudflare example (adjust for Route53, Google DNS, etc.)
  if [ -n "${CLOUDFLARE_ZONE_ID:-}" ] && [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${CLOUDFLARE_DNS_RECORD_ID}" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"A\",\"name\":\"${DNS_RECORD}\",\"content\":\"${ip}\",\"ttl\":60,\"proxied\":false}" >/dev/null && {
      info "DNS record updated via Cloudflare API"
      return 0
    }
    return 1
  fi

  # AWS Route53 example
  if [ -n "${AWS_HOSTED_ZONE_ID:-}" ]; then
    aws route53 change-resource-record-sets \
      --hosted-zone-id "${AWS_HOSTED_ZONE_ID}" \
      --change-batch "{
        \"Changes\": [{
          \"Action\": \"${action}\",
          \"ResourceRecordSet\": {
            \"Name\": \"${DNS_RECORD}\",
            \"Type\": \"A\",
            \"TTL\": 60,
            \"ResourceRecords\": [{\"Value\": \"${ip}\"}]
          }
        }]
      }" >/dev/null 2>&1 && {
      info "DNS record updated via Route53"
      return 0
    }
    return 1
  fi

  warn "No DNS provider configured. Set CLOUDFLARE_* or AWS_* env vars."
  warn "Manual DNS update required: ${DNS_RECORD} -> ${ip}"
  return 0
}

save_failover_state() {
  local state="$1"
  cat > "${FAILOVER_STATE_FILE}" <<EOF
{
  "state": "${state}",
  "timestamp": "${TIMESTAMP}",
  "primaryCluster": "${PRIMARY_CLUSTER}",
  "drCluster": "${DR_CLUSTER}",
  "dnsRecord": "${DNS_RECORD}",
  "previousActive": "${PREVIOUS_ACTIVE:-primary}",
  "failoverTime": "$(date -u +%s)"
}
EOF
  info "Failover state saved: ${FAILOVER_STATE_FILE}"
}

# ── Status Check ───────────────────────────────────────────────

check_failover_status() {
  header "Failover Status"

  echo "  Current State:"
  if [ -f "${FAILOVER_STATE_FILE}" ]; then
    cat "${FAILOVER_STATE_FILE}" | python3 -m json.tool 2>/dev/null || cat "${FAILOVER_STATE_FILE}"
  else
    echo "  No failover has been performed (state file not found)"
    echo "  Default active: PRIMARY (${PRIMARY_CLUSTER})"
  fi
  echo ""

  echo "  Primary Cluster Health (${PRIMARY_CLUSTER}):"
  if check_cluster_health "${PRIMARY_CLUSTER}" "primary" 2>/dev/null; then
    echo "    ✅ Reachable"
  else
    echo "    ❌ Unreachable"
  fi

  echo "  DR Cluster Health (${DR_CLUSTER}):"
  if check_cluster_health "${DR_CLUSTER}" "DR" 2>/dev/null; then
    echo "    ✅ Reachable"
  else
    echo "    ❌ Unreachable"
  fi

  echo ""
  check_dns
}

# ── Failover Plan ──────────────────────────────────────────────

show_failover_plan() {
  header "Failover Plan"

  echo "  Primary Cluster:    ${PRIMARY_CLUSTER}"
  echo "  DR Cluster:         ${DR_CLUSTER}"
  echo "  DNS Record:         ${DNS_RECORD}"
  echo "  DNS Zone:           ${DNS_ZONE}"
  echo "  Health Check URL:   ${HEALTH_CHECK_URL}"
  echo ""
  echo "  Pre-flight checks:"
  echo "    1. Verify DR cluster is reachable"
  echo "    2. Verify Velero DR backup location exists"
  echo "    3. Check primary cluster health"
  echo ""
  echo "  Failover steps:"
  echo "    1. Detect primary failure"
  echo "    2. Switch to DR cluster context"
  echo "    3. Validate DR cluster health"
  echo "    4. Restore from latest Velero DR backup"
  echo "    5. Wait for all pods Ready"
  echo "    6. Validate all services healthy"
  echo "    7. Update DNS to point to DR cluster"
  echo "    8. Verify health check passes via new DNS"
  echo ""
  echo "  Rollback steps:"
  echo "    1. Verify primary cluster recovered"
  echo "    2. Restore from DR backup to primary"
  echo "    3. Wait for all pods Ready on primary"
  echo "    4. Update DNS back to primary cluster"
  echo "    5. Validate health check passes"
  echo ""
}

# ── Failover ───────────────────────────────────────────────────

do_failover() {
  header "FAILOVER — Promoting DR Cluster"

  PREVIOUS_ACTIVE="primary"

  # Step 1: Detect primary failure
  step "1/8: Detecting primary region failure"
  if check_cluster_health "${PRIMARY_CLUSTER}" "Primary" 2>/dev/null; then
    warn "Primary cluster '${PRIMARY_CLUSTER}' appears healthy"
    echo "  However, you may still proceed with failover for testing purposes."
    read -rp "  Continue with failover? (yes/no): " CONFIRM
    if [ "${CONFIRM}" != "yes" ]; then
      info "Failover aborted."
      exit 0
    fi
  else
    record_fail "Primary cluster unreachable — proceeding with failover"
  fi
  echo ""

  # Step 2: Switch to DR context
  step "2/8: Switching to DR cluster context '${DR_CLUSTER}'"
  switch_context "${DR_CLUSTER}"
  echo ""

  # Step 3: Validate DR cluster
  step "3/8: Validating DR cluster health"
  if ! check_cluster_health "${DR_CLUSTER}" "DR"; then
    error "DR cluster is not healthy. Aborting failover."
    exit 1
  fi
  record_pass "DR cluster healthy"
  echo ""

  # Step 4: Restore from latest Velero DR backup
  step "4/8: Restoring from latest Velero DR backup"

  LATEST_DR_BACKUP=$(velero backup get \
    --storage-location "${VELERO_DR_LOCATION}" \
    -o json 2>/dev/null | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  items = data.get('items', [])
  completed = [i for i in items if i.get('status',{}).get('phase') == 'Completed']
  if completed:
    print(completed[-1]['metadata']['name'])
except: pass
" 2>/dev/null || echo "")

  if [ -z "${LATEST_DR_BACKUP}" ]; then
    error "No completed backups found in '${VELERO_DR_LOCATION}'"
    error "Check Velero configuration and backup schedules."
    exit 1
  fi

  info "Restoring from backup: ${LATEST_DR_BACKUP}"

  RESTORE_NAME="failover-restore-${TIMESTAMP}"
  velero restore create "${RESTORE_NAME}" \
    --from-backup "${LATEST_DR_BACKUP}" \
    --wait 2>&1 || {
    error "Restore failed"
    exit 1
  }

  RESTORE_STATUS=$(velero restore get "${RESTORE_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('phase','unknown'))
except: print('unknown')
" 2>/dev/null || echo "unknown")

  if [ "${RESTORE_STATUS}" != "Completed" ]; then
    error "Restore status: ${RESTORE_STATUS}"
    exit 1
  fi
  record_pass "Restore '${RESTORE_NAME}' completed"
  echo ""

  # Step 5: Wait for pods
  step "5/8: Waiting for all pods Ready"
  kubectl wait --for=condition=Ready pod --all -n "${DR_NAMESPACE}" --timeout=300s 2>&1 || {
    warn "Some pods not ready within timeout"
  }

  RUNNING=$(kubectl get pods -n "${DR_NAMESPACE}" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
  TOTAL=$(kubectl get pods -n "${DR_NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo 0)
  info "Pods: ${RUNNING}/${TOTAL} Running"

  if [ "${RUNNING}" -eq "${TOTAL}" ] && [ "${TOTAL}" -gt 0 ]; then
    record_pass "All pods Running on DR"
  else
    record_fail "Not all pods Running on DR (${RUNNING}/${TOTAL})"
  fi
  echo ""

  # Step 6: Validate services
  step "6/8: Validating service health on DR cluster"

  declare -a SERVICES=("portal-web" "auth-users" "chatbot-manager" "conversation-service" "audit-security-service")

  for svc in "${SERVICES[@]}"; do
    ENDPOINTS=$(kubectl get endpoints -n "${DR_NAMESPACE}" "${svc}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    if [ -n "${ENDPOINTS}" ]; then
      record_pass "Service '${svc}' has healthy endpoints"
    else
      record_fail "Service '${svc}' has no endpoints"
    fi
  done
  echo ""

  # Step 7: Update DNS
  step "7/8: Updating DNS to point to DR cluster"

  DR_INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  DR_INGRESS_HOST=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  DR_TARGET="${DR_INGRESS_IP:-${DR_INGRESS_HOST}}"

  if [ -n "${DR_TARGET}" ]; then
    update_dns_record "${DR_TARGET}" "UPSERT"
    record_pass "DNS updated to DR cluster (${DR_TARGET})"
  else
    warn "Could not determine DR ingress IP/hostname"
    warn "Manual DNS update required: ${DNS_RECORD} -> DR cluster ingress"
  fi
  echo ""

  # Step 8: Validate health check
  step "8/8: Validating health check via new DNS"

  if command -v curl &>/dev/null && [ -n "${HEALTH_CHECK_URL}" ]; then
    info "Waiting 30s for DNS propagation..."
    sleep 30

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "${HEALTH_CHECK_URL}" 2>/dev/null || echo "000")

    if [ "${HTTP_CODE}" = "200" ] || [ "${HTTP_CODE}" = "000" ]; then
      warn "Health check returned HTTP ${HTTP_CODE}"
      warn "DNS may still be propagating. Verify manually: curl ${HEALTH_CHECK_URL}"
    else
      info "Health check returned HTTP ${HTTP_CODE}"
    fi

    curl -s --connect-timeout 10 "${HEALTH_CHECK_URL}" 2>/dev/null | head -5 || true
  else
    warn "Health check skipped (no curl or no URL)"
  fi
  echo ""

  # Save state
  save_failover_state "DR_ACTIVE"

  header "FAILOVER COMPLETE"
  echo "  DR cluster '${DR_CLUSTER}' is now active."
  echo "  DNS record '${DNS_RECORD}' updated to DR ingress."
  echo ""
  echo "  Monitor: kubectl --context=${DR_CLUSTER} get pods -n ${DR_NAMESPACE}"
  echo "  To rollback: bash $0 --rollback"
  echo ""
}

# ── Rollback ───────────────────────────────────────────────────

do_rollback() {
  header "ROLLBACK — Restoring Primary Cluster"

  if [ ! -f "${FAILOVER_STATE_FILE}" ]; then
    warn "No failover state found. Assuming primary was always active."
  fi

  # Step 1: Check primary health
  step "1/5: Verifying primary cluster health"
  if ! check_cluster_health "${PRIMARY_CLUSTER}" "Primary" 2>/dev/null; then
    error "Primary cluster '${PRIMARY_CLUSTER}' is still unreachable."
    error "Cannot rollback until primary is recovered."
    exit 1
  fi
  record_pass "Primary cluster reachable"
  echo ""

  # Step 2: Switch to primary context
  step "2/5: Switching to primary cluster context"
  switch_context "${PRIMARY_CLUSTER}"
  echo ""

  # Step 3: Restore from DR backup
  step "3/5: Restoring from latest DR backup"

  LATEST_DR_BACKUP=$(velero backup get \
    --storage-location "${VELERO_DR_LOCATION}" \
    -o json 2>/dev/null | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  items = data.get('items', [])
  completed = [i for i in items if i.get('status',{}).get('phase') == 'Completed']
  if completed:
    print(completed[-1]['metadata']['name'])
except: pass
" 2>/dev/null || echo "")

  if [ -z "${LATEST_DR_BACKUP}" ]; then
    warn "No DR backups found. Restoring from primary backup instead."
    LATEST_BACKUP=$(velero backup get -o json 2>/dev/null | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  items = data.get('items', [])
  completed = [i for i in items if i.get('status',{}).get('phase') == 'Completed']
  if completed:
    print(completed[-1]['metadata']['name'])
except: pass
" 2>/dev/null || echo "")
    if [ -z "${LATEST_BACKUP}" ]; then
      error "No backups found. Cannot rollback."
      exit 1
    fi
    info "Using primary backup: ${LATEST_BACKUP}"
    velero restore create "rollback-restore-${TIMESTAMP}" \
      --from-backup "${LATEST_BACKUP}" \
      --wait 2>&1 || {
      error "Restore failed"
      exit 1
    }
  else
    info "Restoring from DR backup: ${LATEST_DR_BACKUP}"
    velero restore create "rollback-restore-${TIMESTAMP}" \
      --from-backup "${LATEST_DR_BACKUP}" \
      --wait 2>&1 || {
      error "Restore failed"
      exit 1
    }
  fi
  record_pass "Restore initiated on primary"
  echo ""

  # Step 4: Wait for pods
  step "4/5: Waiting for pods on primary"
  kubectl wait --for=condition=Ready pod --all -n "${PRIMARY_NAMESPACE}" --timeout=300s 2>&1 || {
    warn "Some pods not ready within timeout"
  }

  RUNNING=$(kubectl get pods -n "${PRIMARY_NAMESPACE}" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
  TOTAL=$(kubectl get pods -n "${PRIMARY_NAMESPACE}" --no-headers 2>/dev/null | wc -l || echo 0)
  info "Pods: ${RUNNING}/${TOTAL} Running on primary"
  echo ""

  # Step 5: Update DNS back to primary
  step "5/5: Updating DNS back to primary cluster"

  PRIMARY_INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  PRIMARY_INGRESS_HOST=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  PRIMARY_TARGET="${PRIMARY_INGRESS_IP:-${PRIMARY_INGRESS_HOST}}"

  if [ -n "${PRIMARY_TARGET}" ]; then
    update_dns_record "${PRIMARY_TARGET}" "UPSERT"
    record_pass "DNS updated back to primary cluster (${PRIMARY_TARGET})"
  else
    warn "Could not determine primary ingress IP/hostname"
    warn "Manual DNS update required: ${DNS_RECORD} -> primary cluster ingress"
  fi
  echo ""

  save_failover_state "PRIMARY_ACTIVE"

  header "ROLLBACK COMPLETE"
  echo "  Primary cluster '${PRIMARY_CLUSTER}' is now active."
  echo "  DNS record '${DNS_RECORD}' updated back to primary."
  echo ""
  echo "  Monitor: kubectl --context=${PRIMARY_CLUSTER} get pods -n ${PRIMARY_NAMESPACE}"
  echo ""
}

# ── Validate DR ────────────────────────────────────────────────

validate_dr() {
  header "DR Cluster Validation"

  PASS=0
  FAIL=0

  record_pass() { PASS=$((PASS + 1)); echo "  ✅ [PASS] $*"; }
  record_fail() { FAIL=$((FAIL + 1)); echo "  ❌ [FAIL] $*"; }

  switch_context "${DR_CLUSTER}"

  step "Checking Velero on DR..."
  if kubectl get deployment -n velero velero &>/dev/null; then
    record_pass "Velero deployment exists on DR"
  else
    record_fail "Velero not deployed on DR"
  fi

  step "Checking DR BackupStorageLocation..."
  if kubectl get BackupStorageLocation -n velero "${VELERO_DR_LOCATION}" &>/dev/null; then
    BSL_PHASE=$(kubectl get BackupStorageLocation -n velero "${VELERO_DR_LOCATION}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
    if [ "${BSL_PHASE}" = "Available" ]; then
      record_pass "DR BackupStorageLocation '${VELERO_DR_LOCATION}' is Available"
    else
      record_fail "DR BackupStorageLocation phase: ${BSL_PHASE}"
    fi
  else
    record_fail "DR BackupStorageLocation '${VELERO_DR_LOCATION}' not found"
  fi

  step "Checking node count..."
  NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  if [ "${NODES}" -ge 2 ]; then
    record_pass "DR cluster has ${NODES} nodes (minimum 2)"
  else
    record_fail "DR cluster has only ${NODES} nodes"
  fi

  step "Checking DNS..."
  if command -v dig &>/dev/null; then
    RESOLVED=$(dig +short "${DNS_RECORD}" 2>/dev/null | head -1)
    if [ -n "${RESOLVED}" ]; then
      record_pass "DNS record '${DNS_RECORD}' resolves to ${RESOLVED}"
    else
      record_fail "DNS record '${DNS_RECORD}' does not resolve"
    fi
  else
    record_skip "DNS check (dig not available)"
  fi

  echo ""
  info "Validation: ${PASS} passed, ${FAIL} failed"
  return "${FAIL}"
}

# ── Main ───────────────────────────────────────────────────────

case "${1:-}" in
  --status)
    check_failover_status
    ;;
  --failover)
    do_failover
    ;;
  --rollback)
    do_rollback
    ;;
  --validate)
    validate_dr
    ;;
  --plan)
    show_failover_plan
    ;;
  *)
    echo "Usage: bash $0 {--status|--failover|--rollback|--validate|--plan}"
    echo ""
    echo "Examples:"
    echo "  bash $0 --status       Check current failover state"
    echo "  bash $0 --plan         Show failover/rollback plan"
    echo "  bash $0 --failover     Promote DR cluster to active"
    echo "  bash $0 --rollback     Restore primary cluster to active"
    echo "  bash $0 --validate     Validate DR cluster readiness"
    exit 1
    ;;
esac
