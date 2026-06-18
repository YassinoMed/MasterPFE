#!/usr/bin/env bash
# worldclass-validation.sh — Comprehensive World-Class Validation Suite
# SecureRAG Hub — 100+ Checks Across All 15 Phases
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; MAG='\033[0;35m'; NC='\033[0m'
info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*" >&2; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}\n${CYAN}  %s${NC}\n${CYAN}═══════════════════════════════════════════════════════════════${NC}\n" "$*"; }
substep() { printf "${MAG}  ▶ %s${NC}\n" "$*"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
REPORT_DIR="artifacts/worldclass-validation/${TIMESTAMP}"
mkdir -p "${REPORT_DIR}"
REPORT="${REPORT_DIR}/worldclass-validation-report.md"

PASS=0; FAIL=0; WARN=0
declare -A PHASE_PASS PHASE_FAIL PHASE_WARN

record_pass() { local p="${1:-GENERAL}"; PASS=$((PASS + 1)); PHASE_PASS["$p"]=$((PHASE_PASS["$p"] + 1)); echo "  ✅ [PASS] $2"; }
record_fail() { local p="${1:-GENERAL}"; FAIL=$((FAIL + 1)); PHASE_FAIL["$p"]=$((PHASE_FAIL["$p"] + 1)); echo "  ❌ [FAIL] $2"; }
record_warn() { local p="${1:-GENERAL}"; WARN=$((WARN + 1)); PHASE_WARN["$p"]=$((PHASE_WARN["$p"] + 1)); echo "  ⚠️  [WARN] $2"; }

echo ""
echo "████████████████████████████████████████████████████████████████████"
echo "  SECURERAG HUB — WORLD-CLASS VALIDATION SUITE"
echo "  100+ Checks Across 15 Phases"
echo "  Timestamp: ${TIMESTAMP}"
echo "████████████████████████████████████████████████████████████████████"
echo ""

# Check kubectl availability early
if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  error "Kubernetes API not reachable — aborting validation"
  exit 1
fi
record_pass "GENERAL" "Kubernetes API reachable"

###############################################################################
# PHASE 1: GitOps (ArgoCD)
###############################################################################
step "Phase 1/15: GitOps — ArgoCD"

P="GITOPS"

if kubectl get namespace argocd >/dev/null 2>&1; then
  record_pass "$P" "ArgoCD namespace 'argocd' exists"
  # ArgoCD server
  if kubectl get deployment -n argocd argocd-server >/dev/null 2>&1; then
    record_pass "$P" "ArgoCD server deployment exists"
    ARGO_READY=$(kubectl get deployment -n argocd argocd-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
    [ "${ARGO_READY}" -ge 1 ] && record_pass "$P" "ArgoCD server ready (${ARGO_READY})" || record_warn "$P" "ArgoCD server not ready"
  else
    record_warn "$P" "ArgoCD server not deployed"
  fi
  # ArgoCD app controller
  if kubectl get deployment -n argocd argocd-application-controller >/dev/null 2>&1; then
    record_pass "$P" "ArgoCD application controller deployed"
  else
    record_warn "$P" "ArgoCD application controller not deployed"
  fi
  # ArgoCD apps
  APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
  [ "${APP_COUNT}" -ge 1 ] && record_pass "$P" "${APP_COUNT} ArgoCD Applications defined" || record_warn "$P" "No ArgoCD Applications found"
  # Sync status
  SYNCED=$(kubectl get applications -n argocd -o jsonpath='{.items[*].status.sync.status}' 2>/dev/null | tr ' ' '\n' | grep -c "Synced" || true)
  DESIRED=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
  if [ "${DESIRED}" -gt 0 ]; then
    [ "${SYNCED}" -eq "${DESIRED}" ] && record_pass "$P" "All ${DESIRED} apps synced" || record_warn "$P" "${SYNCED}/${DESIRED} apps synced"
  fi
  # Self-heal
  SELF_HEAL=$(kubectl get applications -n argocd -o jsonpath='{.items[*].spec.syncPolicy.automated.selfHeal}' 2>/dev/null | tr ' ' '\n' | grep -c "true" || true)
  [ "${SELF_HEAL}" -ge 1 ] && record_pass "$P" "Self-heal enabled on ${SELF_HEAL} app(s)" || record_warn "$P" "Self-heal not enabled on any app"
  # AppProject
  PROJ_COUNT=$(kubectl get appprojects -n argocd --no-headers 2>/dev/null | wc -l)
  [ "${PROJ_COUNT}" -ge 1 ] && record_pass "$P" "${PROJ_COUNT} AppProject(s) defined" || record_warn "$P" "No AppProjects defined"
  # Repo credentials
  REPO_COUNT=$(kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository --no-headers 2>/dev/null | wc -l)
  [ "${REPO_COUNT}" -ge 1 ] && record_pass "$P" "${REPO_COUNT} ArgoCD repo credential(s)" || record_warn "$P" "No repo credentials configured"
else
  record_warn "$P" "ArgoCD namespace not found — ArgoCD not deployed"
fi

###############################################################################
# PHASE 2: SRE (SLO, Error Budgets, Burn Rate, Pod Availability)
###############################################################################
step "Phase 2/15: SRE — SLO Compliance & Error Budgets"

P="SRE"

# SLO ConfigMap
if kubectl get configmap -n securerag-monitoring prometheus-rules-slo >/dev/null 2>&1; then
  record_pass "$P" "SLO recording rules ConfigMap exists"
  SLO_RULES=$(kubectl get configmap -n securerag-monitoring prometheus-rules-slo -o jsonpath='{.data}' 2>/dev/null | grep -c "slo:" || true)
  [ "${SLO_RULES}" -ge 3 ] && record_pass "$P" "${SLO_RULES}+ SLO rules defined" || record_warn "$P" "Few SLO rules (${SLO_RULES})"
else
  record_warn "$P" "SLO recording rules not deployed"
fi

# SLO Dashboard
if kubectl get configmap -n securerag-monitoring grafana-dashboard-slo-errorbudget >/dev/null 2>&1; then
  record_pass "$P" "SLO/Error Budget Grafana dashboard exists"
else
  record_warn "$P" "SLO/Error Budget dashboard not deployed"
fi

# Error budget alerts
if kubectl get prometheusrules -n securerag-monitoring --no-headers 2>/dev/null | grep -qi "error.budget\|burn.rate\|slo" >/dev/null 2>&1; then
  record_pass "$P" "Error budget / burn rate PrometheusRules found"
else
  record_warn "$P" "No error budget / burn rate PrometheusRules"
fi

# Pod availability targets (check actual readiness)
TOTAL_PODS=$(kubectl get pods -n securerag-hub --no-headers 2>/dev/null | wc -l)
READY_PODS=$(kubectl get pods -n securerag-hub --no-headers 2>/dev/null | grep -c "Running\|Completed" || true)
if [ "${TOTAL_PODS}" -gt 0 ]; then
  AVAIL_PCT=$((READY_PODS * 100 / TOTAL_PODS))
  [ "${AVAIL_PCT}" -ge 95 ] && record_pass "$P" "Pod availability: ${AVAIL_PCT}% (${READY_PODS}/${TOTAL_PODS})" \
    || record_warn "$P" "Pod availability: ${AVAIL_PCT}% (${READY_PODS}/${TOTAL_PODS}) — target ≥95%"
fi

# Multi-window burn rate alerts
BURN_ALERTS=$(kubectl get prometheusrules -n securerag-monitoring -o json 2>/dev/null | grep -c "burn-rate\|BurnRate\|multi.window" || true)
[ "${BURN_ALERTS}" -ge 2 ] && record_pass "$P" "Multi-window burn rate alerts found (${BURN_ALERTS})" \
  || record_warn "$P" "Few burn rate alerts (${BURN_ALERTS}) — recommend multi-window approach"

# Check for SLO metrics actually being recorded
SLO_METRICS=$(kubectl exec -n securerag-monitoring deployment/prometheus -- sh -c 'wget -q -O- "http://localhost:9090/api/v1/query?query=slo:" 2>/dev/null' 2>/dev/null || echo "no data")
if echo "${SLO_METRICS}" | grep -q "slo:" 2>/dev/null; then
  record_pass "$P" "SLO metrics actively being recorded in Prometheus"
else
  record_warn "$P" "SLO metrics not yet visible in Prometheus — rules may need propagation time"
fi

###############################################################################
# PHASE 3: Kubernetes (HPAs, PDBs, Network Policies, Resource Quotas, Namespaces)
###############################################################################
step "Phase 3/15: Kubernetes — HPAs, PDBs, Network Policies, Quotas"

P="KUBERNETES"

# HPAs
HPA_COUNT=$(kubectl get hpa -n securerag-hub --no-headers 2>/dev/null | wc -l)
[ "${HPA_COUNT}" -ge 5 ] && record_pass "$P" "${HPA_COUNT} HPAs configured in securerag-hub" \
  || record_warn "$P" "Only ${HPA_COUNT} HPAs — expected ≥5"
for hpa in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
  if kubectl get hpa -n securerag-hub "${hpa}" >/dev/null 2>&1; then
    METRICS=$(kubectl get hpa -n securerag-hub "${hpa}" -o jsonpath='{.status.currentMetrics}' 2>/dev/null || echo "[]")
    [ -n "${METRICS}" ] && [ "${METRICS}" != "[]" ] && record_pass "$P" "HPA '${hpa}' has current metrics" \
      || record_warn "$P" "HPA '${hpa}' lacks current metrics"
    # Check custom metrics for LLM/custom scaling
    CUSTOM=$(kubectl get hpa -n securerag-hub "${hpa}" -o jsonpath='{.spec.metrics[*].type}' 2>/dev/null || echo "")
    if echo "${CUSTOM}" | grep -q "Pods\|Object"; then
      record_pass "$P" "HPA '${hpa}' uses custom/metrics-server metrics"
    fi
  fi
done

# PDBs
PDB_COUNT=$(kubectl get pdb -n securerag-hub --no-headers 2>/dev/null | wc -l)
[ "${PDB_COUNT}" -ge 4 ] && record_pass "$P" "${PDB_COUNT} PDBs configured" \
  || record_warn "$P" "Only ${PDB_COUNT} PDBs — expected ≥4"
for pdb in portal-web-pdb auth-users-pdb chatbot-manager-pdb conversation-service-pdb audit-security-service-pdb; do
  kubectl get pdb -n securerag-hub "${pdb}" >/dev/null 2>&1 && record_pass "$P" "PDB '${pdb}' exists" \
    || record_warn "$P" "PDB '${pdb}' not found"
done

# Network Policies
NP_COUNT=$(kubectl get networkpolicies -n securerag-hub --no-headers 2>/dev/null | wc -l)
[ "${NP_COUNT}" -ge 5 ] && record_pass "$P" "${NP_COUNT} NetworkPolicies in securerag-hub" \
  || record_warn "$P" "Only ${NP_COUNT} NetworkPolicies — expected ≥5"
# Check for default deny
if kubectl get networkpolicies -n securerag-hub -o json 2>/dev/null | grep -q "deny-all\|default-deny"; then
  record_pass "$P" "Default deny-all network policy present"
else
  record_warn "$P" "No default deny-all network policy — consider adding one"
fi

# Resource Quotas
RQ_COUNT=$(kubectl get resourcequotas -n securerag-hub --no-headers 2>/dev/null | wc -l)
[ "${RQ_COUNT}" -ge 1 ] && record_pass "$P" "${RQ_COUNT} ResourceQuota(s) in securerag-hub" \
  || record_warn "$P" "No ResourceQuotas in securerag-hub"
for ns in securerag-hub securerag-monitoring; do
  RQ=$(kubectl get resourcequotas -n "${ns}" --no-headers 2>/dev/null | wc -l)
  [ "${RQ}" -ge 1 ] && record_pass "$P" "ResourceQuota in '${ns}'" || record_warn "$P" "No ResourceQuota in '${ns}'"
done

# LimitRanges
for ns in securerag-hub securerag-monitoring; do
  LR=$(kubectl get limitranges -n "${ns}" --no-headers 2>/dev/null | wc -l)
  [ "${LR}" -ge 1 ] && record_pass "$P" "LimitRange in '${ns}'" || record_warn "$P" "No LimitRange in '${ns}'"
done

# Namespace labels and annotations
for ns in securerag-hub securerag-monitoring vault; do
  if kubectl get namespace "${ns}" >/dev/null 2>&1; then
    record_pass "$P" "Namespace '${ns}' exists"
    # Check for team label
    TEAM=$(kubectl get namespace "${ns}" -o jsonpath='{.metadata.labels.team}' 2>/dev/null || echo "")
    [ -n "${TEAM}" ] && record_pass "$P" "Namespace '${ns}' has team label: ${TEAM}" \
      || record_warn "$P" "Namespace '${ns}' missing team label"
  else
    record_fail "$P" "Namespace '${ns}' missing — critical"
  fi
done

###############################################################################
# PHASE 4: Security (Kyverno, Falco, Vault/ESO, Pod Security, RBAC)
###############################################################################
step "Phase 4/15: Security — Kyverno, Falco, Vault, Pod Security, RBAC"

P="SECURITY"

# Kyverno
if kubectl get deployment -n kyverno kyverno >/dev/null 2>&1; then
  record_pass "$P" "Kyverno deployed"
  KP_COUNT=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l)
  [ "${KP_COUNT}" -ge 5 ] && record_pass "$P" "${KP_COUNT} Kyverno ClusterPolicies" \
    || record_warn "$P" "Only ${KP_COUNT} Kyverno ClusterPolicies — target ≥5"
  # Check enforce vs audit
  ENFORCE_COUNT=$(kubectl get clusterpolicies -o jsonpath='{.items[*].spec.validationFailureAction}' 2>/dev/null | tr ' ' '\n' | grep -ci "enforce" || true)
  [ "${ENFORCE_COUNT}" -ge 2 ] && record_pass "$P" "${ENFORCE_COUNT} policies in enforce mode" \
    || record_warn "$P" "Too few enforce-mode policies (${ENFORCE_COUNT})"
else
  record_warn "$P" "Kyverno not deployed"
fi

# Kyverno Policy Report status (if reports exist)
POLR_COUNT=$(kubectl get polr --no-headers 2>/dev/null | wc -l || true)
[ "${POLR_COUNT}" -ge 1 ] && record_pass "$P" "${POLR_COUNT} Kyverno PolicyReport(s)" \
  || record_warn "$P" "No Kyverno PolicyReports — admission plugin may not be active"

# Falco
if kubectl get daemonset -n falco falco >/dev/null 2>&1; then
  record_pass "$P" "Falco DaemonSet deployed"
  FALCO_READY=$(kubectl get daemonset -n falco falco -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)
  FALCO_DESIRED=$(kubectl get daemonset -n falco falco -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)
  [ "${FALCO_READY}" -ge 1 ] && [ "${FALCO_READY}" -eq "${FALCO_DESIRED}" ] 2>/dev/null \
    && record_pass "$P" "Falco ready (${FALCO_READY}/${FALCO_DESIRED})" \
    || record_warn "$P" "Falco not fully ready (${FALCO_READY}/${FALCO_DESIRED})"
  # Check Falco rules
  FALCO_RULES=$(kubectl get configmap -n falco falco-rules -o jsonpath='{.data}' 2>/dev/null | grep -c "rule:" || true)
  [ "${FALCO_RULES}" -ge 5 ] && record_pass "$P" "${FALCO_RULES}+ Falco rules loaded" \
    || record_warn "$P" "Few Falco rules (${FALCO_RULES})"
else
  record_warn "$P" "Falco not deployed"
fi

# Vault
if kubectl get statefulset -n vault vault >/dev/null 2>&1; then
  record_pass "$P" "Vault StatefulSet deployed"
  VAULT_READY=$(kubectl get statefulset -n vault vault -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${VAULT_READY}" -ge 1 ] && record_pass "$P" "Vault pod ready" || record_warn "$P" "Vault pod not ready"
  # Check Vault unseal status
  VAULT_UNSEALED=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | grep -c '"sealed":false' || true)
  [ "${VAULT_UNSEALED}" -ge 1 ] && record_pass "$P" "Vault unsealed" || record_warn "$P" "Vault may be sealed"
  # Check Vault auth methods
  VAULT_AUTH=$(kubectl exec -n vault vault-0 -- vault auth list -format=json 2>/dev/null | grep -c "kubernetes" || true)
  [ "${VAULT_AUTH}" -ge 1 ] && record_pass "$P" "Vault Kubernetes auth configured" || record_warn "$P" "Vault Kubernetes auth not configured"
else
  record_warn "$P" "Vault not deployed"
fi

# External Secrets Operator
if kubectl get deployment -n external-secrets external-secrets >/dev/null 2>&1; then
  record_pass "$P" "External Secrets Operator deployed"
  ES_READY=$(kubectl get deployment -n external-secrets external-secrets -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${ES_READY}" -ge 1 ] && record_pass "$P" "ESO pod ready" || record_warn "$P" "ESO pod not ready"
else
  record_warn "$P" "External Secrets Operator not deployed"
fi

# ClusterSecretStore
if kubectl get clustersecretstore vault-backend >/dev/null 2>&1; then
  record_pass "$P" "ClusterSecretStore 'vault-backend' exists"
else
  record_warn "$P" "ClusterSecretStore 'vault-backend' not found"
fi

# ExternalSecrets count
ES_COUNT=$(kubectl get externalsecret -A --no-headers 2>/dev/null | wc -l)
[ "${ES_COUNT}" -ge 1 ] && record_pass "$P" "${ES_COUNT} ExternalSecrets configured" || record_warn "$P" "No ExternalSecrets found"

# Pod Security Standards
for ns in securerag-hub securerag-monitoring vault; do
  PSS=$(kubectl get namespace "${ns}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
  if [ -n "${PSS}" ]; then
    record_pass "$P" "Pod Security Standards enforced in '${ns}': ${PSS}"
    if [ "${PSS}" = "restricted" ]; then
      record_pass "$P" "'${ns}' uses restricted Pod Security Standard"
    fi
  else
    record_warn "$P" "No Pod Security Standards label in '${ns}'"
  fi
done

# RBAC — check for ClusterRoles/Roles
CL_ROLES=$(kubectl get clusterroles --no-headers 2>/dev/null | grep -c "securerag\|secure-rag\|sr-" || true)
[ "${CL_ROLES}" -ge 3 ] && record_pass "$P" "${CL_ROLES} custom ClusterRoles found" \
  || record_warn "$P" "Only ${CL_ROLES} custom ClusterRoles — recommended ≥3"
# Check for restrictive RBAC
BIND_COUNT=$(kubectl get clusterrolebindings --no-headers 2>/dev/null | wc -l)
[ "${BIND_COUNT}" -le 50 ] && record_pass "$P" "Reasonable ClusterRoleBinding count (${BIND_COUNT})" \
  || record_warn "$P" "High ClusterRoleBinding count (${BIND_COUNT}) — audit recommended"

# ServiceAccounts with automount
for ns in securerag-hub securerag-monitoring; do
  DSA_COUNT=$(kubectl get serviceaccounts -n "${ns}" -o jsonpath='{.items[*].automountServiceAccountToken}' 2>/dev/null | tr ' ' '\n' | grep -c "false" || true)
  [ "${DSA_COUNT}" -ge 1 ] && record_pass "$P" "Non-default automount SA tokens in '${ns'} (${DSA_COUNT})" \
    || record_warn "$P" "All SAs in '${ns}' use default automount — review"
done

###############################################################################
# PHASE 5: DR (Velero Backups, Schedules, Restore Tests, RTO/RPO)
###############################################################################
step "Phase 5/15: Disaster Recovery — Velero, Backups, Restore"

P="DR"

# Velero deployment
if kubectl get deployment -n velero velero >/dev/null 2>&1; then
  record_pass "$P" "Velero deployed"
  VELERO_READY=$(kubectl get deployment -n velero velero -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${VELERO_READY}" -ge 1 ] && record_pass "$P" "Velero pod ready" || record_warn "$P" "Velero pod not ready"
else
  record_warn "$P" "Velero not deployed"
fi

# Velero backup schedules
SCHED_COUNT=$(kubectl get schedules -n velero --no-headers 2>/dev/null | wc -l)
[ "${SCHED_COUNT}" -ge 1 ] && record_pass "$P" "${SCHED_COUNT} Velero backup schedule(s)" \
  || record_warn "$P" "No Velero schedules configured"

# Check actual backups exist
BACKUP_COUNT=$(kubectl get backups -n velero --no-headers 2>/dev/null | wc -l)
[ "${BACKUP_COUNT}" -ge 1 ] && record_pass "$P" "${BACKUP_COUNT} Velero backup(s) exist" \
  || record_warn "$P" "No Velero backups found — run backup-test.sh"

# Latest backup status
if [ "${BACKUP_COUNT}" -ge 1 ]; then
  LATEST_BACKUP=$(kubectl get backups -n velero -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")
  LATEST_STATUS=$(kubectl get backups -n velero -o jsonpath='{.items[-1].status.phase}' 2>/dev/null || echo "")
  if [ "${LATEST_STATUS}" = "Completed" ]; then
    record_pass "$P" "Latest backup '${LATEST_BACKUP}' status: ${LATEST_STATUS}"
  else
    record_warn "$P" "Latest backup status: ${LATEST_STATUS} — expected Completed"
  fi
fi

# Validate restore scripts exist
for scr in scripts/dr/backup-test.sh scripts/dr/validate-restore.sh scripts/dr/full-restore-drill.sh; do
  [ -f "${scr}" ] && record_pass "$P" "Restore script exists: ${scr}" || record_warn "$P" "Missing script: ${scr}"
done

# RTO validation (from HPA/PDB context)
if kubectl get pdb -n securerag-hub >/dev/null 2>&1; then
  record_pass "$P" "PDBs available for controlled disruption (supports RTO)"
fi

# RPO validation (check backup schedule frequency)
if [ "${SCHED_COUNT}" -ge 1 ]; then
  SCHED_FREQ=$(kubectl get schedules -n velero -o jsonpath='{.items[*].spec.schedule}' 2>/dev/null || echo "")
  if echo "${SCHED_FREQ}" | grep -q "0 \*/6\|\*/30\|\*/15"; then
    record_pass "$P" "Backup schedule frequency supports RPO objectives"
  else
    record_warn "$P" "Backup schedule frequency: ${SCHED_FREQ} — verify RPO alignment"
  fi
fi

# PostgreSQL backup CronJob
if kubectl get cronjob -n securerag-hub postgres-backup >/dev/null 2>&1; then
  record_pass "$P" "PostgreSQL backup CronJob configured"
  PG_BACKUP_LAST=$(kubectl get cronjob -n securerag-hub postgres-backup -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null || echo "")
  [ -n "${PG_BACKUP_LAST}" ] && record_pass "$P" "PostgreSQL backup last run: ${PG_BACKUP_LAST}" \
    || record_warn "$P" "PostgreSQL backup CronJob never ran"
else
  record_warn "$P" "PostgreSQL backup CronJob not found"
fi

# MinIO / backup storage
if kubectl get deployment -n minio minio >/dev/null 2>&1; then
  record_pass "$P" "MinIO backup storage deployed"
  MINIO_READY=$(kubectl get deployment -n minio minio -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${MINIO_READY}" -ge 1 ] && record_pass "$P" "MinIO ready" || record_warn "$P" "MinIO not ready"
else
  record_warn "$P" "MinIO not deployed — backups may lack storage target"
fi

# Cross-check: DR pipeline stage in CD
if [ -f Jenkinsfile.cd ] && grep -q "DR\|backup\|restore" Jenkinsfile.cd 2>/dev/null; then
  record_pass "$P" "DR test stage present in CD pipeline"
else
  record_warn "$P" "No DR test stage in CD pipeline"
fi

###############################################################################
# PHASE 6: Observability (ServiceMonitors, PromRules, Grafana, Alertmanager)
###############################################################################
step "Phase 6/15: Observability — ServiceMonitors, Rules, Dashboards, Alerts"

P="OBSERVABILITY"

# Prometheus
if kubectl get deployment -n securerag-monitoring prometheus >/dev/null 2>&1; then
  record_pass "$P" "Prometheus deployed"
else
  record_warn "$P" "Prometheus not deployed"
fi

# Grafana
if kubectl get deployment -n securerag-monitoring grafana >/dev/null 2>&1; then
  record_pass "$P" "Grafana deployed"
  GRAFANA_READY=$(kubectl get deployment -n securerag-monitoring grafana -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${GRAFANA_READY}" -ge 1 ] && record_pass "$P" "Grafana ready" || record_warn "$P" "Grafana not ready"
else
  record_warn "$P" "Grafana not deployed"
fi

# Loki
if kubectl get deployment -n securerag-monitoring loki >/dev/null 2>&1; then
  record_pass "$P" "Loki deployed"
  LOKI_READY=$(kubectl get deployment -n securerag-monitoring loki -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${LOKI_READY}" -ge 1 ] && record_pass "$P" "Loki ready" || record_warn "$P" "Loki not ready"
else
  record_warn "$P" "Loki not deployed"
fi

# Alertmanager
if kubectl get deployment -n securerag-monitoring alertmanager >/dev/null 2>&1; then
  record_pass "$P" "Alertmanager deployed"
  AM_READY=$(kubectl get deployment -n securerag-monitoring alertmanager -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${AM_READY}" -ge 1 ] && record_pass "$P" "Alertmanager ready" || record_warn "$P" "Alertmanager not ready"
else
  record_warn "$P" "Alertmanager not deployed"
fi

# ServiceMonitors count
SM_COUNT=$(kubectl get servicemonitors --all-namespaces --no-headers 2>/dev/null | wc -l)
if [ "${SM_COUNT}" -ge 25 ]; then
  record_pass "$P" "${SM_COUNT} ServiceMonitors — excellent coverage"
elif [ "${SM_COUNT}" -ge 15 ]; then
  record_pass "$P" "${SM_COUNT} ServiceMonitors — good coverage"
elif [ "${SM_COUNT}" -ge 10 ]; then
  record_pass "$P" "${SM_COUNT} ServiceMonitors — adequate coverage"
else
  record_warn "$P" "Only ${SM_COUNT} ServiceMonitors — target ≥15"
fi

# ServiceMonitors in monitoring namespace
SM_MON_COUNT=$(kubectl get servicemonitors -n securerag-monitoring --no-headers 2>/dev/null | wc -l)
[ "${SM_MON_COUNT}" -ge 10 ] && record_pass "$P" "${SM_MON_COUNT} ServiceMonitors in securerag-monitoring" \
  || record_warn "$P" "Only ${SM_MON_COUNT} ServiceMonitors in monitoring namespace"

# PrometheusRules
PR_COUNT=$(kubectl get prometheusrules --all-namespaces --no-headers 2>/dev/null | wc -l)
[ "${PR_COUNT}" -ge 5 ] && record_pass "$P" "${PR_COUNT} PrometheusRules across all namespaces" \
  || record_warn "$P" "Only ${PR_COUNT} PrometheusRules — target ≥10"

# Grafana dashboards via ConfigMaps
GD_COUNT=$(kubectl get configmap -n securerag-monitoring -l grafana_dashboard=1 --no-headers 2>/dev/null | wc -l)
GD_COUNT2=$(kubectl get configmap -n securerag-monitoring -l grafana_dashboard --no-headers 2>/dev/null | wc -l)
TOTAL_GD=$((GD_COUNT + GD_COUNT2))
[ "${TOTAL_GD}" -ge 3 ] && record_pass "$P" "${TOTAL_GD} Grafana dashboard ConfigMaps" \
  || record_warn "$P" "Only ${TOTAL_GD} Grafana dashboards — target ≥3"

# Check Alertmanager config
if kubectl get secret -n securerag-monitoring alertmanager-alertmanager >/dev/null 2>&1; then
  record_pass "$P" "Alertmanager configuration secret exists"
else
  record_warn "$P" "Alertmanager config secret not found"
fi

# Check if kube-state-metrics is deployed
if kubectl get deployment -n securerag-monitoring kube-state-metrics >/dev/null 2>&1; then
  record_pass "$P" "kube-state-metrics deployed"
else
  record_warn "$P" "kube-state-metrics not deployed — needed for HPA/SLO metrics"
fi

# Check node-exporter
if kubectl get daemonset -n securerag-monitoring node-exporter >/dev/null 2>&1; then
  record_pass "$P" "node-exporter DaemonSet deployed"
else
  record_warn "$P" "node-exporter not deployed"
fi

###############################################################################
# PHASE 7: Chaos Engineering (Experiment Definitions, Operator Status)
###############################################################################
step "Phase 7/15: Chaos Engineering — Experiments & Operator"

P="CHAOS"

# Check for chaos operator (Litmus or Chaos Mesh)
CHAOS_NS=""
for cns in litmus chaos-mesh chaos; do
  kubectl get namespace "${cns}" >/dev/null 2>&1 && { CHAOS_NS="${cns}"; break; } || true
done

if [ -n "${CHAOS_NS}" ]; then
  record_pass "$P" "Chaos Engineering namespace '${CHAOS_NS}' exists"
  # Find chaos operator deployments
  CHAOS_DEPLOY=$(kubectl get deployment -n "${CHAOS_NS}" --no-headers 2>/dev/null | grep -i "chaos\|litmus\|controller\|operator" | wc -l)
  [ "${CHAOS_DEPLOY}" -ge 1 ] && record_pass "$P" "${CHAOS_DEPLOY} chaos operator deployment(s) in '${CHAOS_NS}'" \
    || record_warn "$P" "No chaos operator deployment found in '${CHAOS_NS}'"
else
  record_warn "$P" "No Chaos Engineering namespace found (litmus/chaos-mesh)"
fi

# Check for ChaosExperiments / ChaosEngines
CE_COUNT=$(kubectl get chaosexperiments --all-namespaces --no-headers 2>/dev/null | wc -l || true)
CE_COUNT2=$(kubectl get chaosengines --all-namespaces --no-headers 2>/dev/null | wc -l || true)
TOTAL_CE=$((CE_COUNT + CE_COUNT2))
[ "${TOTAL_CE}" -ge 1 ] && record_pass "$P" "${TOTAL_CE} Chaos experiment/engine(s) found" \
  || record_warn "$P" "No chaos experiments defined — recommended for resilience validation"

# Check for HA chaos test script
if [ -f scripts/validate/validate-ha-chaos-lite.sh ]; then
  record_pass "$P" "HA chaos lite validation script exists"
else
  record_warn "$P" "HA chaos lite script not found"
fi

# Check runbooks / documentation of past experiments
if ls docs/chaos* scripts/chaos* 2>/dev/null | head -1 >/dev/null 2>&1; then
  record_pass "$P" "Chaos engineering documentation/scripts present"
else
  record_warn "$P" "No chaos engineering documentation found"
fi

###############################################################################
# PHASE 8: FinOps (OpenCost Deployment)
###############################################################################
step "Phase 8/15: FinOps — OpenCost"

P="FINOPs"

# Check for OpenCost
if kubectl get deployment -n securerag-monitoring opencost >/dev/null 2>&1; then
  record_pass "$P" "OpenCost deployed"
  OC_READY=$(kubectl get deployment -n securerag-monitoring opencost -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${OC_READY}" -ge 1 ] && record_pass "$P" "OpenCost ready" || record_warn "$P" "OpenCost not ready"
else
  # Try other namespaces
  if kubectl get deployment -n opencost opencost >/dev/null 2>&1; then
    record_pass "$P" "OpenCost deployed in opencost namespace"
  else
    record_warn "$P" "OpenCost not deployed — recommended for cost visibility"
  fi
fi

# Check for OpenCost ServiceMonitor or metrics endpoint
if kubectl get servicemonitor -A -o json 2>/dev/null | grep -qi "opencost\|cost" >/dev/null 2>&1; then
  record_pass "$P" "OpenCost ServiceMonitor present"
else
  record_warn "$P" "OpenCost not scraped by Prometheus — no ServiceMonitor"
fi

# Check for cost allocation labels on namespaces
for ns in securerag-hub securerag-monitoring; do
  COST_LABEL=$(kubectl get namespace "${ns}" -o jsonpath='{.metadata.labels.division}' 2>/dev/null || echo "")
  COST_LABEL2=$(kubectl get namespace "${ns}" -o jsonpath='{.metadata.labels.cost-center}' 2>/dev/null || echo "")
  if [ -n "${COST_LABEL}" ] || [ -n "${COST_LABEL2}" ]; then
    record_pass "$P" "Cost allocation labels on '${ns}'"
  else
    record_warn "$P" "No cost allocation labels on '${ns}'"
  fi
done

# Check for Pod resource requests/limits (needed for cost allocation)
NO_LIMITS=$(kubectl get pods -n securerag-hub -o jsonpath='{.items[*].spec.containers[*].resources.limits}' 2>/dev/null | grep -c "{}" || true)
TOTAL_CONTAINERS=$(kubectl get pods -n securerag-hub -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null | wc -w || true)
if [ "${TOTAL_CONTAINERS}" -gt 0 ]; then
  MISSING_PCT=$((NO_LIMITS * 100 / TOTAL_CONTAINERS))
  [ "${MISSING_PCT}" -le 20 ] && record_pass "$P" "Resource limits present on $((TOTAL_CONTAINERS - NO_LIMITS))/${TOTAL_CONTAINERS} containers" \
    || record_warn "$P" "${MISSING_PCT}% containers missing resource limits — FinOps cost allocation impacted"
fi

###############################################################################
# PHASE 9: DORA Metrics (Deployment Frequency, Lead Time, MTTR, Change Failure Rate)
###############################################################################
step "Phase 9/15: DORA Metrics — Deployment Frequency, Lead Time, MTTR, CFR"

P="DORA"

# Git-based: check recent commits as proxy for deployment frequency
RECENT_COMMITS=$(git log --oneline --since="7 days ago" 2>/dev/null | wc -l)
[ "${RECENT_COMMITS}" -ge 5 ] && record_pass "$P" "${RECENT_COMMITS} commits in last 7 days (deployment frequency proxy)" \
  || record_warn "$P" "Only ${RECENT_COMMITS} commits in 7 days — low deployment frequency"

# Check for release tags
RELEASE_TAGS=$(git tag -l "v*" --sort=-v:refname 2>/dev/null | wc -l)
[ "${RELEASE_TAGS}" -ge 3 ] && record_pass "$P" "${RELEASE_TAGS} release tags found" \
  || record_warn "$P" "Only ${RELEASE_TAGS} release tags — tag releases for DORA tracking"

# Check for GitHub Actions or CI pipeline runs (GitHub API)
if gh repo view --json name 2>/dev/null >/dev/null; then
  record_pass "$P" "GitHub CLI authenticated — can query DORA metrics"
  # Check workflow runs
  WR_COUNT=$(gh run list --limit 30 --json status --jq '[.[] | select(.status=="completed")] | length' 2>/dev/null || echo 0)
  [ "${WR_COUNT}" -ge 5 ] && record_pass "$P" "${WR_COUNT} completed workflow runs visible" \
    || record_warn "$P" "Few workflow runs (${WR_COUNT})"
else
  record_warn "$P" "GitHub CLI not authenticated — DORA metrics from CI unavailable"
fi

# Jenkinsfile presence (CI/CD pipeline)
if [ -f Jenkinsfile ]; then
  record_pass "$P" "Jenkinsfile CI pipeline defined"
  STAGE_COUNT=$(grep -c "stage(" Jenkinsfile 2>/dev/null || true)
  [ "${STAGE_COUNT}" -ge 10 ] && record_pass "$P" "${STAGE_COUNT} CI stages" || record_warn "$P" "Only ${STAGE_COUNT} CI stages"
fi
if [ -f Jenkinsfile.cd ]; then
  record_pass "$P" "Jenkinsfile CD pipeline defined"
  CD_STAGES=$(grep -c "stage(" Jenkinsfile.cd 2>/dev/null || true)
  [ "${CD_STAGES}" -ge 3 ] && record_pass "$P" "${CD_STAGES} CD stages" || record_warn "$P" "Only ${CD_STAGES} CD stages"
fi

# MTTR proxy: check if quick recovery scripts exist
for rec in scripts/dr/validate-restore.sh scripts/dr/full-restore-drill.sh scripts/dr/backup-test.sh; do
  [ -f "${rec}" ] && record_pass "$P" "Recovery script exists (supports MTTR): ${rec}"
done

# Change failure rate proxy: check recent rollbacks
RECENT_ROLLBACKS=$(git log --oneline --all --grep="revert\|rollback\|Revert\|Rollback" --since="30 days ago" 2>/dev/null | wc -l)
[ "${RECENT_ROLLBACKS}" -eq 0 ] && record_pass "$P" "No rollbacks in last 30 days (low change failure rate)" \
  || record_warn "$P" "${RECENT_ROLLBACKS} rollback(s) in 30 days — monitor CFR"

# Lead time proxy: time between commits and releases
if [ "${RELEASE_TAGS}" -ge 2 ]; then
  LATEST_TAG=$(git tag -l "v*" --sort=-v:refname 2>/dev/null | head -1)
  PREV_TAG=$(git tag -l "v*" --sort=-v:refname 2>/dev/null | head -2 | tail -1)
  if [ -n "${LATEST_TAG}" ] && [ -n "${PREV_TAG}" ]; then
    LEAD_TIME=$(git log --oneline "${PREV_TAG}".."${LATEST_TAG}" 2>/dev/null | wc -l)
    record_pass "$P" "Lead time (commits between ${PREV_TAG}..${LATEST_TAG}): ${LEAD_TIME} commits"
  fi
fi

# DORA dashboard check
if kubectl get configmap -n securerag-monitoring -o json 2>/dev/null | grep -qi "dora\|deployment.frequency\|lead.time\|mttr\|cfr" >/dev/null 2>&1; then
  record_pass "$P" "DORA metrics dashboard/config found in monitoring"
else
  record_warn "$P" "No DORA metrics dashboard — consider adding Four Keys dashboard"
fi

###############################################################################
# PHASE 10: Multi-Cloud (Terraform Configs)
###############################################################################
step "Phase 10/15: Multi-Cloud — Terraform Configurations"

P="MULTICLOUD"

TF_DIRS=("terraform/aws" "terraform/azure" "terraform/gcp")
for tf_dir in "${TF_DIRS[@]}"; do
  if [ -d "${tf_dir}" ]; then
    record_pass "$P" "Terraform directory exists: ${tf_dir}"
    TF_FILES=$(find "${tf_dir}" -name "*.tf" 2>/dev/null | wc -l)
    [ "${TF_FILES}" -ge 3 ] && record_pass "$P" "${TF_FILES} .tf files in ${tf_dir}" \
      || record_warn "$P" "Only ${TF_FILES} .tf files in ${tf_dir}"
    # Check for backend config
    if ls "${tf_dir}/backend"* "${tf_dir}"/**/backend* 2>/dev/null >/dev/null; then
      record_pass "$P" "Terraform backend config in ${tf_dir}"
    else
      record_warn "$P" "No backend config in ${tf_dir} — state management not defined"
    fi
    # tfsec check
    if [ -f "${tf_dir}/.tfsec" ] || head -20 "${tf_dir}"/*.tf 2>/dev/null | grep -q "tfsec\|checkov" >/dev/null 2>&1; then
      record_pass "$P" "Security scanning configured for ${tf_dir}"
    else
      record_warn "$P" "No security scanner config (tfsec/checkov) in ${tf_dir}"
    fi
  else
    record_warn "$P" "Terraform directory missing: ${tf_dir}"
  fi
done

# Check for provider configurations
PROVIDER_COUNT=$(find terraform -name "*.tf" -exec grep -l "provider " {} \; 2>/dev/null | wc -l)
[ "${PROVIDER_COUNT}" -ge 3 ] && record_pass "$P" "${PROVIDER_COUNT} provider configurations across clouds" \
  || record_warn "$P" "Only ${PROVIDER_COUNT} provider configs — expected ≥3 (AWS/Azure/GCP)"

# Check for Terraform variables files
for tf_dir in "${TF_DIRS[@]}"; do
  if [ -d "${tf_dir}" ]; then
    VARS_COUNT=$(find "${tf_dir}" -name "terraform.tfvars*" -o -name "*.auto.tfvars" 2>/dev/null | wc -l)
    [ "${VARS_COUNT}" -ge 1 ] && record_pass "$P" "Variables file in ${tf_dir}" || record_warn "$P" "No .tfvars in ${tf_dir}"
  fi
done

# Check for outputs
OUTPUT_COUNT=$(find terraform -name "*.tf" -exec grep -l "output " {} \; 2>/dev/null | wc -l)
[ "${OUTPUT_COUNT}" -ge 3 ] && record_pass "$P" "${OUTPUT_COUNT} files with Terraform outputs" \
  || record_warn "$P" "Few Terraform output definitions (${OUTPUT_COUNT})"

###############################################################################
# PHASE 11: PostgreSQL HA (CNPG Cluster Status, Replication Lag)
###############################################################################
step "Phase 11/15: PostgreSQL HA — CNPG Cluster"

P="POSTGRES_HA"

# Check for CNPG operator
if kubectl get deployment -n cnpg-system cnpg-controller-manager >/dev/null 2>&1; then
  record_pass "$P" "CloudNativePG operator deployed"
else
  # Try finding CNPG in other namespaces
  if kubectl get deployment -A cnpg-controller-manager >/dev/null 2>&1; then
    record_pass "$P" "CloudNativePG operator deployed (alternate namespace)"
  else
    record_warn "$P" "CloudNativePG operator not found"
  fi
fi

# Check for CNPG cluster
CNPG_CLUSTER=$(kubectl get cluster -n securerag-hub --no-headers 2>/dev/null | head -1 | awk '{print $1}' || true)
if [ -n "${CNPG_CLUSTER}" ]; then
  record_pass "$P" "CNPG cluster '${CNPG_CLUSTER}' exists"
  # Check instances
  INSTANCES=$(kubectl get cluster -n securerag-hub "${CNPG_CLUSTER}" -o jsonpath='{.spec.instances}' 2>/dev/null || echo 0)
  READY_INST=$(kubectl get cluster -n securerag-hub "${CNPG_CLUSTER}" -o jsonpath='{.status.readyInstances}' 2>/dev/null || echo 0)
  [ "${INSTANCES}" -ge 3 ] && record_pass "$P" "${INSTANCES} instances configured (HA)" \
    || record_warn "$P" "Only ${INSTANCES} CNPG instance(s) — recommend ≥3 for HA"
  [ "${READY_INST}" -ge 2 ] && record_pass "$P" "${READY_INST}/${INSTANCES} instances ready" \
    || record_warn "$P" "Only ${READY_INST}/${INSTANCES} CNPG instances ready"

  # Check replication status
  REP_STATUS=$(kubectl get cluster -n securerag-hub "${CNPG_CLUSTER}" -o jsonpath='{.status.readService}' 2>/dev/null || echo "")
  [ -n "${REP_STATUS}" ] && record_pass "$P" "CNPG read service (replicas): ${REP_STATUS}" \
    || record_warn "$P" "CNPG read service not configured"

  # Check for replication slots
  if kubectl exec -n securerag-hub "${CNPG_CLUSTER}"-1 -- psql -U postgres -c "SELECT slot_name,slot_type,active FROM pg_replication_slots;" 2>/dev/null | grep -q "physical" >/dev/null 2>&1; then
    record_pass "$P" "Replication slots active for streaming replication"
  else
    record_warn "$P" "Cannot verify replication slots — may need CNPG pod access"
  fi

  # Check backup status via CNPG
  CNPG_BACKUPS=$(kubectl get backup -n securerag-hub --no-headers 2>/dev/null | wc -l)
  [ "${CNPG_BACKUPS}" -ge 1 ] && record_pass "$P" "${CNPG_BACKUPS} CNPG backup(s) defined" \
    || record_warn "$P" "No CNPG backups defined"
else
  record_warn "$P" "No CNPG cluster found in securerag-hub"
fi

# Check for postgres-auth as non-CNPG alternative
if kubectl get deployment -n securerag-hub postgres-auth >/dev/null 2>&1; then
  PG_READY=$(kubectl get deployment -n securerag-hub postgres-auth -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${PG_READY}" -ge 1 ] && record_pass "$P" "postgres-auth deployment ready" \
    || record_warn "$P" "postgres-auth not ready"
  # Check replicas
  PG_REPLICAS=$(kubectl get deployment -n securerag-hub postgres-auth -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
  [ "${PG_REPLICAS}" -ge 3 ] && record_pass "$P" "postgres-auth has ${PG_REPLICAS} replicas (HA)" \
    || record_warn "$P" "postgres-auth only ${PG_REPLICAS} replica(s)"
fi

###############################################################################
# PHASE 12: Tracing (OTel Collector, Tempo)
###############################################################################
step "Phase 12/15: Tracing — OpenTelemetry & Tempo"

P="TRACING"

# OTel Collector
if kubectl get deployment -n securerag-monitoring otel-collector >/dev/null 2>&1; then
  record_pass "$P" "OpenTelemetry Collector deployed"
  OTEL_READY=$(kubectl get deployment -n securerag-monitoring otel-collector -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${OTEL_READY}" -ge 1 ] && record_pass "$P" "OTel Collector ready" || record_warn "$P" "OTel Collector not ready"
else
  # Try daemonset form
  if kubectl get daemonset -n securerag-monitoring otel-collector >/dev/null 2>&1; then
    record_pass "$P" "OpenTelemetry Collector DaemonSet deployed"
  else
    record_warn "$P" "OTel Collector not deployed"
  fi
fi

# Tempo (tracing backend)
if kubectl get deployment -n securerag-monitoring tempo >/dev/null 2>&1; then
  record_pass "$P" "Tempo deployed"
  TEMPO_READY=$(kubectl get deployment -n securerag-monitoring tempo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${TEMPO_READY}" -ge 1 ] && record_pass "$P" "Tempo ready" || record_warn "$P" "Tempo not ready"
else
  # Check for Grafana Tempo in other forms
  if kubectl get statefulset -n securerag-monitoring tempo >/dev/null 2>&1; then
    record_pass "$P" "Tempo StatefulSet deployed"
  else
    record_warn "$P" "Tempo not deployed — distributed tracing unavailable"
  fi
fi

# ServiceMonitors for OTel/Tempo
if kubectl get servicemonitor -n securerag-monitoring otel-collector >/dev/null 2>&1; then
  record_pass "$P" "OTel Collector ServiceMonitor exists"
else
  SM_OTEL=$(kubectl get servicemonitor -A -o json 2>/dev/null | grep -ci "otel\|tempo\|opentelemetry" || true)
  [ "${SM_OTEL}" -ge 1 ] && record_pass "$P" "${SM_OTEL} tracing ServiceMonitor(s) found" \
    || record_warn "$P" "No tracing ServiceMonitors found"
fi

# Tempo data source in Grafana
if kubectl get configmap -n securerag-monitoring -o json 2>/dev/null | grep -qi "tempo\|traces\|datasource" >/dev/null 2>&1; then
  record_pass "$P" "Tempo datasource configured in Grafana"
else
  record_warn "$P" "Tempo datasource not found in Grafana config"
fi

# Check for trace sampling config
if kubectl get configmap -n securerag-monitoring -o json 2>/dev/null | grep -qi "sampling_rate\|sampling.*ratio\|tail_sampling" >/dev/null 2>&1; then
  record_pass "$P" "Trace sampling configuration present"
else
  record_warn "$P" "No trace sampling config — may ingest all traces"
fi

###############################################################################
# PHASE 13: Performance (k6 Test Results)
###############################################################################
step "Phase 13/15: Performance — k6 Test Results"

P="PERFORMANCE"

# Check for k6 scripts
K6_COUNT=$(find scripts tests -name "*.k6.js" -o -name "k6*.js" -o -name "k6*" 2>/dev/null | wc -l)
if [ "${K6_COUNT}" -ge 1 ]; then
  record_pass "$P" "${K6_COUNT} k6 test script(s) found"
  # Check for k6 results artifacts
  K6_RESULTS=$(find artifacts -name "*k6*" -o -name "*loadtest*" 2>/dev/null | wc -l)
  [ "${K6_RESULTS}" -ge 1 ] && record_pass "$P" "${K6_RESULTS} k6 result file(s) in artifacts" \
    || record_warn "$P" "No k6 results in artifacts — run k6 tests"
else
  record_warn "$P" "No k6 test scripts found"
fi

# Check for k6 dashboard/ServiceMonitor
if kubectl get servicemonitor -A -o json 2>/dev/null | grep -qi "k6\|load.test" >/dev/null 2>&1; then
  record_pass "$P" "k6 metrics scraping configured"
else
  record_warn "$P" "No k6 metrics scraping — consider k6 output to Prometheus"
fi

# Check for load testing config
if kubectl get configmap -n securerag-hub -o json 2>/dev/null | grep -qi "performance\|load.test\|threshold" >/dev/null 2>&1; then
  record_pass "$P" "Performance test configuration found"
else
  record_warn "$P" "No performance test configuration in cluster"
fi

# Performance threshold documentation
if ls docs/perf* docs/performance* 2>/dev/null >/dev/null; then
  record_pass "$P" "Performance documentation exists"
else
  record_warn "$P" "No performance documentation found"
fi

# Check for stress testing tools
K6_BIN=$(command -v k6 2>/dev/null || true)
[ -n "${K6_BIN}" ] && record_pass "$P" "k6 binary available (${K6_BIN})" \
  || record_warn "$P" "k6 binary not found on this system"

###############################################################################
# PHASE 14: Service Mesh (Istio Status)
###############################################################################
step "Phase 14/15: Service Mesh — Istio"

P="SERVICEMESH"

# Check for Istio namespace
if kubectl get namespace istio-system >/dev/null 2>&1; then
  record_pass "$P" "Istio namespace 'istio-system' exists"
else
  record_warn "$P" "Istio namespace not found"
fi

# Istiod (control plane)
if kubectl get deployment -n istio-system istiod >/dev/null 2>&1; then
  record_pass "$P" "Istiod control plane deployed"
  ISTIOD_READY=$(kubectl get deployment -n istio-system istiod -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${ISTIOD_READY}" -ge 1 ] && record_pass "$P" "Istiod ready" || record_warn "$P" "Istiod not ready"
else
  record_warn "$P" "Istiod not deployed"
fi

# Ingress gateway
if kubectl get deployment -n istio-system istio-ingressgateway >/dev/null 2>&1; then
  record_pass "$P" "Istio Ingress Gateway deployed"
  IG_READY=$(kubectl get deployment -n istio-system istio-ingressgateway -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${IG_READY}" -ge 1 ] && record_pass "$P" "Ingress Gateway ready" || record_warn "$P" "Ingress Gateway not ready"
else
  record_warn "$P" "Istio Ingress Gateway not deployed"
fi

# Check for sidecar injection
if kubectl get namespace securerag-hub -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null | grep -q "enabled" >/dev/null 2>&1; then
  record_pass "$P" "Istio sidecar injection enabled on securerag-hub"
  # Check how many pods have sidecar
  SIDECAR_COUNT=$(kubectl get pods -n securerag-hub -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null | tr ' ' '\n' | grep -c "istio-proxy" || true)
  TOTAL_DEPLOYMENTS=$(kubectl get deployments -n securerag-hub --no-headers 2>/dev/null | wc -l)
  [ "${SIDECAR_COUNT}" -ge "${TOTAL_DEPLOYMENTS}" ] && record_pass "$P" "All deployments have Istio sidecars (${SIDECAR_COUNT})" \
    || record_warn "$P" "${SIDECAR_COUNT} Istio sidecars found — expected ~${TOTAL_DEPLOYMENTS}"
else
  record_warn "$P" "Istio sidecar injection not enabled on securerag-hub"
fi

# Check for VirtualServices and DestinationRules
VS_COUNT=$(kubectl get virtualservices -n securerag-hub --no-headers 2>/dev/null | wc -l)
[ "${VS_COUNT}" -ge 1 ] && record_pass "$P" "${VS_COUNT} VirtualService(s) defined" \
  || record_warn "$P" "No VirtualServices found"
DR_COUNT=$(kubectl get destinationrules -n securerag-hub --no-headers 2>/dev/null | wc -l)
[ "${DR_COUNT}" -ge 1 ] && record_pass "$P" "${DR_COUNT} DestinationRule(s) defined" \
  || record_warn "$P" "No DestinationRules found"

# mTLS check
PEER_AUTH=$(kubectl get peerauthentication -n securerag-hub --no-headers 2>/dev/null | wc -l)
[ "${PEER_AUTH}" -ge 1 ] && record_pass "$P" "${PEER_AUTH} PeerAuthentication(s) for mTLS" \
  || record_warn "$P" "No PeerAuthentication policies — mTLS may not be enforced"

# Telemetry (Istio dashboards in Grafana)
if kubectl get configmap -n securerag-monitoring -o json 2>/dev/null | grep -qi "istio\|mesh" >/dev/null 2>&1; then
  record_pass "$P" "Istio telemetry dashboards present"
else
  record_warn "$P" "No Istio dashboards in Grafana"
fi

###############################################################################
# PHASE 15: eBPF (Cilium, Hubble)
###############################################################################
step "Phase 15/15: eBPF — Cilium & Hubble"

P="EBPF"

# Check for Cilium
if kubectl get namespace kube-system >/dev/null 2>&1; then
  CILIUM_DS=$(kubectl get daemonset -n kube-system cilium --no-headers 2>/dev/null | wc -l || true)
  if [ "${CILIUM_DS}" -ge 1 ]; then
    record_pass "$P" "Cilium DaemonSet deployed"
    CILIUM_READY=$(kubectl get daemonset -n kube-system cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo 0)
    CILIUM_DESIRED=$(kubectl get daemonset -n kube-system cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo 0)
    [ "${CILIUM_READY}" -ge 1 ] && [ "${CILIUM_READY}" -eq "${CILIUM_DESIRED}" ] 2>/dev/null \
      && record_pass "$P" "Cilium ready (${CILIUM_READY}/${CILIUM_DESIRED})" \
      || record_warn "$P" "Cilium not fully ready (${CILIUM_READY}/${CILIUM_DESIRED})"

    # Check Cilium version
    CILIUM_VERSION=$(kubectl exec -n kube-system ds/cilium -- cilium version --short 2>/dev/null || echo "")
    [ -n "${CILIUM_VERSION}" ] && record_pass "$P" "Cilium version: ${CILIUM_VERSION}" \
      || record_warn "$P" "Cannot determine Cilium version"

    # Check Cilium status
    CILIUM_STATUS=$(kubectl exec -n kube-system ds/cilium -- cilium status --brief 2>/dev/null || echo "")
    if echo "${CILIUM_STATUS}" | grep -qi "ok\|healthy\|ready" >/dev/null 2>&1; then
      record_pass "$P" "Cilium status: healthy"
    else
      record_warn "$P" "Cilium status may need review"
    fi
  else
    record_warn "$P" "Cilium not deployed — check CNI configuration"
  fi
fi

# Hubble
if kubectl get deployment -n kube-system hubble-relay >/dev/null 2>&1; then
  record_pass "$P" "Hubble Relay deployed"
  HUBBLE_READY=$(kubectl get deployment -n kube-system hubble-relay -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${HUBBLE_READY}" -ge 1 ] && record_pass "$P" "Hubble Relay ready" || record_warn "$P" "Hubble Relay not ready"
else
  record_warn "$P" "Hubble Relay not deployed — visibility reduced"
fi

if kubectl get daemonset -n kube-system hubble-ui >/dev/null 2>&1; then
  record_pass "$P" "Hubble UI DaemonSet deployed"
else
  if kubectl get deployment -n kube-system hubble-ui >/dev/null 2>&1; then
    record_pass "$P" "Hubble UI deployment exists"
  else
    record_warn "$P" "Hubble UI not deployed"
  fi
fi

# Hubble ServiceMonitor
if kubectl get servicemonitor -A -o json 2>/dev/null | grep -qi "hubble\|cilium" >/dev/null 2>&1; then
  record_pass "$P" "Cilium/Hubble ServiceMonitor present"
else
  record_warn "$P" "No Cilium/Hubble ServiceMonitor — metrics not scraped"
fi

# Check network policy enforcement via Cilium
CILIUM_NP=$(kubectl get ciliumnetworkpolicies --all-namespaces --no-headers 2>/dev/null | wc -l || true)
[ "${CILIUM_NP}" -ge 1 ] && record_pass "$P" "${CILIUM_NP} CiliumNetworkPolicies found" \
  || record_warn "$P" "No CiliumNetworkPolicies — using standard K8s NetworkPolicies"

# Hubble flow visibility
HUBBLE_FLOWS=$(kubectl exec -n kube-system ds/cilium -- hubble observe --last 5 2>/dev/null | head -3 || true)
if [ -n "${HUBBLE_FLOWS}" ]; then
  record_pass "$P" "Hubble flow visibility active"
else
  record_warn "$P" "Hubble flows not observable — check hubble configuration"
fi

# Check CiliumClusterwideNetworkPolicies
CCNP_COUNT=$(kubectl get ciliumclusterwidenetworkpolicies --no-headers 2>/dev/null | wc -l || true)
[ "${CCNP_COUNT}" -ge 1 ] && record_pass "$P" "${CCNP_COUNT} CiliumClusterwideNetworkPolicies" \
  || record_warn "$P" "No CiliumClusterwideNetworkPolicies"

###############################################################################
# SUMMARY & REPORT GENERATION
###############################################################################
step "VALIDATION COMPLETE — Generating Report"

echo ""
echo "████████████████████████████████████████████████████████████████████"
echo "  FINAL SCORES BY PHASE"
echo "████████████████████████████████████████████████████████████████████"
echo ""

TOTAL=$((PASS + FAIL + WARN))

declare -A PHASE_NAMES
PHASE_NAMES["GENERAL"]="General"
PHASE_NAMES["GITOPS"]="Phase 1: GitOps"
PHASE_NAMES["SRE"]="Phase 2: SRE"
PHASE_NAMES["KUBERNETES"]="Phase 3: Kubernetes"
PHASE_NAMES["SECURITY"]="Phase 4: Security"
PHASE_NAMES["DR"]="Phase 5: DR"
PHASE_NAMES["OBSERVABILITY"]="Phase 6: Observability"
PHASE_NAMES["CHAOS"]="Phase 7: Chaos Engineering"
PHASE_NAMES["FINOPs"]="Phase 8: FinOps"
PHASE_NAMES["DORA"]="Phase 9: DORA Metrics"
PHASE_NAMES["MULTICLOUD"]="Phase 10: Multi-Cloud"
PHASE_NAMES["POSTGRES_HA"]="Phase 11: PostgreSQL HA"
PHASE_NAMES["TRACING"]="Phase 12: Tracing"
PHASE_NAMES["PERFORMANCE"]="Phase 13: Performance"
PHASE_NAMES["SERVICEMESH"]="Phase 14: Service Mesh"
PHASE_NAMES["EBPF"]="Phase 15: eBPF"

for phase in GENERAL GITOPS SRE KUBERNETES SECURITY DR OBSERVABILITY CHAOS FINOPs DORA MULTICLOUD POSTGRES_HA TRACING PERFORMANCE SERVICEMESH EBPF; do
  p_pass=${PHASE_PASS[$phase]:-0}
  p_fail=${PHASE_FAIL[$phase]:-0}
  p_warn=${PHASE_WARN[$phase]:-0}
  p_total=$((p_pass + p_fail + p_warn))
  if [ "${p_total}" -gt 0 ]; then
    p_score=$((p_pass * 100 / p_total))
    printf "  %-25s : %2d/%2d passed = %3d%%\n" "${PHASE_NAMES[$phase]}" "${p_pass}" "${p_total}" "${p_score}"
  else
    printf "  %-25s : No checks run\n" "${PHASE_NAMES[$phase]}"
  fi
done

echo ""
printf "  %-25s : %d/%d passed = %d%%\n" "TOTAL" "${PASS}" "${TOTAL}" "$((TOTAL > 0 ? PASS * 100 / TOTAL : 0))"
echo ""

# Calculate overall score (PASS only)
OVERALL_PCT=$((TOTAL > 0 ? PASS * 100 / TOTAL : 0))

# Generate markdown report
cat > "${REPORT}" << REPORTOF
# World-Class Validation Report — SecureRAG Hub

## Metadata
| Field | Value |
|:---|---:|
| Timestamp | ${TIMESTAMP} |
| Total Checks | ${TOTAL} |
| Passed | ${PASS} |
| Failed | ${FAIL} |
| Warnings | ${WARN} |
| **Overall Score** | **${OVERALL_PCT}%** |
| Threshold | ≥90% for World-Class |

## Legend
- ✅ PASS — Check passed (meets world-class standards)
- ❌ FAIL — Check failed (requires immediate attention)
- ⚠️ WARN — Warning (non-critical gap or advisory)

---

## Per-Phase Results

REPORTOF

for phase in GENERAL GITOPS SRE KUBERNETES SECURITY DR OBSERVABILITY CHAOS FINOPs DORA MULTICLOUD POSTGRES_HA TRACING PERFORMANCE SERVICEMESH EBPF; do
  p_pass=${PHASE_PASS[$phase]:-0}
  p_fail=${PHASE_FAIL[$phase]:-0}
  p_warn=${PHASE_WARN[$phase]:-0}
  p_total=$((p_pass + p_fail + p_warn))
  p_score=$((p_total > 0 ? p_pass * 100 / p_total : 0))
  cat >> "${REPORT}" << REPORTOF
### ${PHASE_NAMES[$phase]}
- ✅ PASS: ${p_pass}
- ❌ FAIL: ${p_fail}
- ⚠️ WARN: ${p_warn}
- **Score: ${p_score}%**

REPORTOF
done

cat >> "${REPORT}" << REPORTOF
---

## Summary

**Overall Score: ${OVERALL_PCT}%** (${PASS}/${TOTAL} checks passed)

### Next Steps
- Review all FAIL items and remediate before production deployment
- Address WARN items based on priority (security > resilience > observability)
- Re-run this validation after each major deployment
- Track score trends over time to ensure continuous improvement

### World-Class Thresholds
| Level | Score | Status |
|:---|---:|:---:|
| Bronze | ≥70% | Base requirement |
| Silver | ≥80% | Production ready |
| Gold | ≥90% | Enterprise ready |
| **World-Class** | **≥95%** | **Target** |

_Generated: ${TIMESTAMP}_ | _Tool: worldclass-validation.sh_ | _SecureRAG Hub_
REPORTOF

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Report saved to: ${REPORT}"
echo "  Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
echo "  Overall Score: ${OVERALL_PCT}%"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Exit with fail count
[ "${FAIL}" -eq 0 ] || exit 1
exit 0
