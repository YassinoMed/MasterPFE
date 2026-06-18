#!/usr/bin/env bash
# bootstrap-cluster-validation.sh — Full Kubernetes Cluster Validation
# SecureRAG Hub — Enterprise Production Readiness
# Validates all components on kind/K3s/EKS clusters
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "${CYAN}[STEP]${NC}  %s\n" "$*"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
REPORT_DIR="artifacts/validation/${TIMESTAMP}"
mkdir -p "${REPORT_DIR}"
SUMMARY="${REPORT_DIR}/cluster-validation-summary.md"

PASS=0; FAIL=0; WARN=0

record_pass() { PASS=$((PASS + 1)); echo "  ✅ [PASS] $*"; }
record_fail() { FAIL=$((FAIL + 1)); echo "  ❌ [FAIL] $*"; }
record_warn() { WARN=$((WARN + 1)); echo "  ⚠️  [WARN] $*"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  SECURERAG HUB — FULL CLUSTER VALIDATION"
echo "  Timestamp: ${TIMESTAMP}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── 1. Cluster reachability ──────────────────────────────────────
step "1/12: Cluster Reachability"
if kubectl version --request-timeout=5s >/dev/null 2>&1; then
  record_pass "Kubernetes API reachable"
  kubectl cluster-info --request-timeout=5s 2>/dev/null | head -3 || true
else
  record_fail "Kubernetes API not reachable — check kubeconfig"
fi

# ── 2. Core components ────────────────────────────────────────────
step "2/12: Core Components (metrics-server, coredns)"
for dep in metrics-server coredns; do
  if kubectl get deployment -n kube-system "${dep}" >/dev/null 2>&1; then
    record_pass "${dep} deployed in kube-system"
  else
    # Try other namespaces
    if kubectl get deployment -A "${dep}" >/dev/null 2>&1; then
      record_pass "${dep} deployed (alternate namespace)"
    else
      record_warn "${dep} not found — may affect cluster functionality"
    fi
  fi
done

if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  record_pass "metrics-server API available"
else
  record_warn "metrics-server API not available — HPA requires metrics-server"
fi

# ── 3. Critical namespaces ────────────────────────────────────────
step "3/12: Critical Namespaces"
for ns in securerag-hub securerag-monitoring vault external-secrets velero minio; do
  if kubectl get namespace "${ns}" >/dev/null 2>&1; then
    record_pass "Namespace '${ns}' exists"
  else
    case "${ns}" in
      vault|external-secrets|velero|minio)
        record_warn "Namespace '${ns}' not found — may not be deployed yet"
        ;;
      *)
        record_fail "Namespace '${ns}' not found — critical!"
        ;;
    esac
  fi
done

# ── 4. Business services ──────────────────────────────────────────
step "4/12: Business Services (Deployments)"
for svc in portal-web auth-users chatbot-manager conversation-service audit-security-service api-gateway llm-orchestrator postgres-auth qdrant; do
  if kubectl get deployment -n securerag-hub "${svc}" >/dev/null 2>&1; then
    READY=$(kubectl get deployment -n securerag-hub "${svc}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
    DESIRED=$(kubectl get deployment -n securerag-hub "${svc}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
    if [ "${READY}" -ge "${DESIRED}" ] 2>/dev/null; then
      record_pass "${svc} ready (${READY}/${DESIRED})"
    else
      record_warn "${svc} partially ready (${READY}/${DESIRED})"
    fi
  else
    record_warn "${svc} not deployed in securerag-hub"
  fi
done

# ── 5. HPA validation ─────────────────────────────────────────────
step "5/12: HPA — Horizontal Pod Autoscaler"
for hpa in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
  if kubectl get hpa -n securerag-hub "${hpa}" >/dev/null 2>&1; then
    record_pass "HPA '${hpa}' configured"
    # Check for metrics
    CMD=$(kubectl get hpa -n securerag-hub "${hpa}" -o jsonpath='{.status.currentMetrics}' 2>/dev/null || echo "")
    if [ -n "${CMD}" ] && [ "${CMD}" != "[]" ]; then
      record_pass "HPA '${hpa}' has current metrics"
    else
      record_warn "HPA '${hpa}' has no current metrics — check metrics-server"
    fi
  else
    record_warn "HPA '${hpa}' not configured"
  fi
done

# ── 6. PDB validation ─────────────────────────────────────────────
step "6/12: PDB — PodDisruptionBudget"
for pdb in portal-web-pdb auth-users-pdb chatbot-manager-pdb conversation-service-pdb audit-security-service-pdb; do
  if kubectl get pdb -n securerag-hub "${pdb}" >/dev/null 2>&1; then
    record_pass "PDB '${pdb}' configured"
  else
    record_warn "PDB '${pdb}' not configured"
  fi
done

# ── 7. Network policies ───────────────────────────────────────────
step "7/12: Network Policies"
NP_COUNT=$(kubectl get networkpolicies -n securerag-hub --no-headers 2>/dev/null | wc -l)
if [ "${NP_COUNT}" -ge 5 ]; then
  record_pass "${NP_COUNT} network policies in securerag-hub"
else
  record_warn "Only ${NP_COUNT} network policies — expected 5+"
fi

# ── 8. Observability stack ────────────────────────────────────────
step "8/12: Observability Stack"
for dep in prometheus grafana loki alertmanager; do
  if kubectl get deployment -n securerag-monitoring "${dep}" >/dev/null 2>&1; then
    record_pass "${dep} deployed in securerag-monitoring"
  else
    record_warn "${dep} not found"
  fi
done

# Check ServiceMonitors
SM_COUNT=$(kubectl get servicemonitors -n securerag-monitoring --no-headers 2>/dev/null | wc -l)
if [ "${SM_COUNT}" -ge 10 ]; then
  record_pass "${SM_COUNT} ServiceMonitors configured"
else
  record_warn "Only ${SM_COUNT} ServiceMonitors — target: 15+"
fi

# Check PrometheusRules
PR_COUNT=$(kubectl get prometheusrules -n securerag-monitoring --no-headers 2>/dev/null | wc -l)
if [ "${PR_COUNT}" -ge 5 ]; then
  record_pass "${PR_COUNT} PrometheusRules configured"
else
  record_warn "Only ${PR_COUNT} PrometheusRules — target: 10+"
fi

# ── 9. SLO & Error Budgets ────────────────────────────────────────
step "9/12: SLO/Error Budget Recording Rules"
if kubectl get configmap -n securerag-monitoring prometheus-rules-slo >/dev/null 2>&1; then
  record_pass "SLO recording rules ConfigMap exists"
else
  record_warn "SLO recording rules not deployed"
fi

if kubectl get configmap -n securerag-monitoring grafana-dashboard-slo-errorbudget >/dev/null 2>&1; then
  record_pass "SLO/Error Budget Grafana dashboard ConfigMap exists"
else
  record_warn "SLO/Error Budget dashboard not deployed"
fi

# ── 10. Secrets Management (Vault + ESO) ──────────────────────────
step "10/12: Secrets Management"
if kubectl get statefulset -n vault vault >/dev/null 2>&1; then
  record_pass "Vault StatefulSet deployed"
  VAULT_READY=$(kubectl get statefulset -n vault vault -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  [ "${VAULT_READY}" -ge 1 ] && record_pass "Vault pod ready" || record_warn "Vault pod not ready"
else
  record_warn "Vault not deployed — run: bash scripts/deploy/deploy-vault-and-eso.sh"
fi

if kubectl get deployment -n external-secrets external-secrets >/dev/null 2>&1; then
  record_pass "External Secrets Operator deployed"
else
  record_warn "External Secrets Operator not deployed"
fi

if kubectl get clustersecretstore vault-backend >/dev/null 2>&1; then
  record_pass "ClusterSecretStore 'vault-backend' exists"
else
  record_warn "ClusterSecretStore 'vault-backend' not found"
fi

# ExternalSecrets check
ES_COUNT=$(kubectl get externalsecret -A --no-headers 2>/dev/null | wc -l)
[ "${ES_COUNT}" -ge 1 ] && record_pass "${ES_COUNT} ExternalSecrets configured" || record_warn "No ExternalSecrets found"

# ── 11. Backup & DR (Velero) ──────────────────────────────────────
step "11/12: Backup & Disaster Recovery"
if kubectl get deployment -n velero velero >/dev/null 2>&1; then
  record_pass "Velero deployed"
  SCHED_COUNT=$(kubectl get schedules -n velero --no-headers 2>/dev/null | wc -l)
  [ "${SCHED_COUNT}" -ge 1 ] && record_pass "${SCHED_COUNT} Velero backup schedules configured" || record_warn "No Velero schedules found"
else
  record_warn "Velero not deployed — run: bash scripts/deploy/deploy-velero.sh"
fi

if kubectl get cronjob -n securerag-hub postgres-backup >/dev/null 2>&1; then
  record_pass "PostgreSQL backup CronJob configured"
else
  record_warn "PostgreSQL backup CronJob not found"
fi

# ── 12. Security posture ──────────────────────────────────────────
step "12/12: Security Posture"
# Kyverno
if kubectl get deployment -n kyverno kyverno >/dev/null 2>&1; then
  record_pass "Kyverno deployed"
  KP_COUNT=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l)
  [ "${KP_COUNT}" -ge 5 ] && record_pass "${KP_COUNT} Kyverno ClusterPolicies" || record_warn "Only ${KP_COUNT} Kyverno ClusterPolicies"
fi

# Falco
if kubectl get deployment -n falco falco >/dev/null 2>&1; then
  record_pass "Falco deployed"
else
  record_warn "Falco not deployed"
fi

# Pod Security Standards
for ns in securerag-hub securerag-monitoring vault; do
  PSS=$(kubectl get namespace "${ns}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "none")
  if [ -n "${PSS}" ] && [ "${PSS}" != "none" ]; then
    record_pass "Pod Security Standards enforced in '${ns}': ${PSS}"
  else
    record_warn "No Pod Security Standards in '${ns}'"
  fi
done

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VALIDATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
echo "  Report: ${SUMMARY}"
echo ""

# Generate summary
cat > "${SUMMARY}" << SUMMARYEOF
# Cluster Validation Report — ${TIMESTAMP}

## Summary
| Metric | Value |
|:---|---:|
| Passed | ${PASS} |
| Failed | ${FAIL} |
| Warnings | ${WARN} |
| Total Checks | $((PASS + FAIL + WARN)) |
| Score | $((PASS * 100 / (PASS + FAIL + WARN + 1)))% |

## Legend
- ✅ [PASS] — Check passed
- ❌ [FAIL] — Check failed (needs attention)
- ⚠️  [WARN] — Warning (non-critical gap)

## Details

### 1. Cluster Reachability
### 2. Core Components
### 3. Critical Namespaces
### 4. Business Services
### 5. HPA
### 6. PDB
### 7. Network Policies
### 8. Observability Stack
### 9. SLO/Error Budgets
### 10. Secrets Management (Vault + ESO)
### 11. Backup & DR (Velero)
### 12. Security Posture

_Generated: ${TIMESTAMP}_ | _Tool: bootstrap-cluster-validation.sh_
SUMMARYEOF

echo "  Full details logged to: ${REPORT_DIR}/"
echo ""

# Exit with fail count
[ "${FAIL}" -eq 0 ] || exit 1
exit 0
