#!/usr/bin/env bash
# generate-compliance-report.sh — Global verification and compliance report generator
#
# Usage:
#   bash scripts/validate/generate-compliance-report.sh

set -euo pipefail

REPORT_DIR="reports"
mkdir -p "${REPORT_DIR}"
REPORT_FILE="${REPORT_DIR}/global-compliance-report.md"

# Results tracking
CHECKS_EXECUTED=0
CHECKS_PASSED=0
CHECKS_FAILED=0
RESULTS=""

add_result() {
  local category="$1"
  local name="$2"
  local status="$3"
  local detail="$4"
  CHECKS_EXECUTED=$((CHECKS_EXECUTED + 1))
  if [ "${status}" = "PASS" ]; then
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    RESULTS="${RESULTS}| ${category} | ${name} | ✅ PASS | ${detail} |\n"
    printf "[\e[32mPASS\e[0m] %s: %s\n" "${category}" "${name}"
  else
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    RESULTS="${RESULTS}| ${category} | ${name} | ❌ FAIL | ${detail} |\n"
    printf "[\e[31mFAIL\e[0m] %s: %s (%s)\n" "${category}" "${name}" "${detail}"
  fi
}

# --- 1. FALCO RUNTIME SECURITY ---
if kubectl get ds falco -n falco >/dev/null 2>&1; then
  ready=$(kubectl get ds falco -n falco -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  desired=$(kubectl get ds falco -n falco -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
  if [ "$ready" -gt 0 ] && [ "$ready" -eq "$desired" ]; then
    add_result "Falco" "DaemonSet Running" "PASS" "Ready: ${ready}/${desired}"
  else
    add_result "Falco" "DaemonSet Running" "FAIL" "Ready: ${ready}/${desired}"
  fi
else
  add_result "Falco" "DaemonSet Running" "FAIL" "DaemonSet not found"
fi

if kubectl get deployment falcosidekick -n falco >/dev/null 2>&1; then
  ready=$(kubectl get deployment falcosidekick -n falco -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$ready" -gt 0 ]; then
    add_result "Falco" "Falcosidekick Running" "PASS" "Replicas: ${ready}"
  else
    add_result "Falco" "Falcosidekick Running" "FAIL" "No ready replicas"
  fi
else
  add_result "Falco" "Falcosidekick Running" "FAIL" "Deployment not found"
fi

if kubectl get ds falco -n falco -o jsonpath='{.spec.template.spec.containers[0].ports[?(@.name=="metrics")].containerPort}' 2>/dev/null | grep -q "8765"; then
  add_result "Falco" "Metrics Port Exposed" "PASS" "Port 8765 exposed"
else
  add_result "Falco" "Metrics Port Exposed" "FAIL" "Port 8765 not exposed"
fi

if kubectl get configmap falcosidekick-config -n falco -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep -q "wazuh-manager"; then
  add_result "Falco" "Syslog Wazuh Egress" "PASS" "Configured to forward alerts to Wazuh syslog"
else
  add_result "Falco" "Syslog Wazuh Egress" "FAIL" "Syslog host not configured to wazuh-manager"
fi

# --- 2. KYVERNO ADMISSION CONTROL ---
if kubectl get deployment kyverno-admission-controller -n kyverno >/dev/null 2>&1; then
  ready=$(kubectl get deployment kyverno-admission-controller -n kyverno -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$ready" -gt 0 ]; then
    add_result "Kyverno" "Admission Controller Pods" "PASS" "Admission controller healthy"
  else
    add_result "Kyverno" "Admission Controller Pods" "FAIL" "Admission controller unhealthy"
  fi
else
  add_result "Kyverno" "Admission Controller Pods" "FAIL" "Admission controller deployment not found"
fi

policies_count=$(kubectl get clusterpolicies -o name 2>/dev/null | wc -l || echo "0")
if [ "$policies_count" -ge 8 ]; then
  add_result "Kyverno" "ClusterPolicies Count" "PASS" "${policies_count} policies installed"
else
  add_result "Kyverno" "ClusterPolicies Count" "FAIL" "Only ${policies_count}/8 policies installed"
fi

enforce_count=$(kubectl get clusterpolicies -o json 2>/dev/null | jq '[.items[].spec.validationFailureAction == "Enforce"] | select(. != null) | length' 2>/dev/null || echo "0")
if [ "$enforce_count" -gt 0 ]; then
  add_result "Kyverno" "Enforce Mode Active" "PASS" "${enforce_count} policies in Enforce mode"
else
  add_result "Kyverno" "Enforce Mode Active" "FAIL" "All policies in Audit mode"
fi

# --- 3. SUPPLY CHAIN & SCANNING EVIDENCE ---
if [ -f "security/reports/gitleaks.json" ]; then
  add_result "Supply Chain" "Gitleaks Report" "PASS" "Report found"
else
  add_result "Supply Chain" "Gitleaks Report" "FAIL" "Report not found"
fi

if [ -f "security/reports/semgrep.json" ]; then
  add_result "Supply Chain" "Semgrep Report" "PASS" "Report found"
else
  add_result "Supply Chain" "Semgrep Report" "FAIL" "Report not found"
fi

if [ -f "security/reports/trivy-fs.json" ]; then
  add_result "Supply Chain" "Trivy Report" "PASS" "Report found"
else
  add_result "Supply Chain" "Trivy Report" "FAIL" "Report not found"
fi

sbom_count=$(find artifacts/sbom -name "*.cyclonedx.json" 2>/dev/null | wc -l || echo "0")
if [ "$sbom_count" -ge 5 ]; then
  add_result "Supply Chain" "CycloneDX SBOMs" "PASS" "${sbom_count} SBOMs generated"
else
  add_result "Supply Chain" "CycloneDX SBOMs" "FAIL" "Only ${sbom_count}/5 SBOMs generated"
fi

sig_count=$(find artifacts/release -name "*.sig" 2>/dev/null | wc -l || echo "0")
if [ "$sig_count" -ge 5 ]; then
  add_result "Supply Chain" "Cosign Signatures" "PASS" "${sig_count} images signed"
else
  add_result "Supply Chain" "Cosign Signatures" "FAIL" "Only ${sig_count}/5 signatures"
fi

if [ -f "artifacts/release/provenance-statement.json" ] || [ -f "artifacts/release/release-evidence.json" ]; then
  add_result "Supply Chain" "SLSA Provenance" "PASS" "Provenance statements generated"
else
  add_result "Supply Chain" "SLSA Provenance" "FAIL" "Provenance statements missing"
fi

if [ -f "scripts/dora/collect-dora-metrics.sh" ] && [ -f "evidence/build-evidence.json" ]; then
  add_result "Supply Chain" "DORA Metrics Collection" "PASS" "Metrics script and pipeline evidence present"
else
  add_result "Supply Chain" "DORA Metrics Collection" "FAIL" "Pipeline evidence files missing"
fi

# --- 4. ARGOCD GITOPS ---
if kubectl get application securerag-root -n argocd >/dev/null 2>&1; then
  sync=$(kubectl get application securerag-root -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
  health=$(kubectl get application securerag-root -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
  if [ "$sync" = "Synced" ] && [ "$health" = "Healthy" ]; then
    add_result "ArgoCD" "Root Application Sync" "PASS" "Synced & Healthy"
  else
    add_result "ArgoCD" "Root Application Sync" "FAIL" "Sync: ${sync} | Health: ${health}"
  fi
else
  add_result "ArgoCD" "Root Application Sync" "FAIL" "securerag-root application not found"
fi

# --- 5. KUBERNETES BASE HARDENING ---
if kubectl get ns securerag-hub >/dev/null 2>&1; then
  add_result "Kubernetes" "securerag-hub Namespace" "PASS" "Namespace present"
else
  add_result "Kubernetes" "securerag-hub Namespace" "FAIL" "Namespace missing"
fi

psa_enforce=$(kubectl get ns securerag-hub -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "none")
if [ "$psa_enforce" = "restricted" ]; then
  add_result "Kubernetes" "Pod Security Admission Enforce" "PASS" "Enforce: restricted"
else
  add_result "Kubernetes" "Pod Security Admission Enforce" "FAIL" "Enforce: ${psa_enforce}"
fi

sa_token_disabled="true"
for sa in sa-portal-web sa-auth-users sa-chatbot-manager sa-conversation-service sa-audit-security-service; do
  if kubectl get serviceaccount "${sa}" -n securerag-hub >/dev/null 2>&1; then
    automount=$(kubectl get serviceaccount "${sa}" -n securerag-hub -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null || echo "true")
    if [ "$automount" != "false" ]; then
      sa_token_disabled="false"
    fi
  fi
done
if [ "$sa_token_disabled" = "true" ]; then
  add_result "Kubernetes" "SA Automount Token Disabled" "PASS" "Automount disabled on workload service accounts"
else
  add_result "Kubernetes" "SA Automount Token Disabled" "FAIL" "One or more service accounts have token automount enabled"
fi

if kubectl get networkpolicy default-deny-all -n securerag-hub >/dev/null 2>&1; then
  add_result "Kubernetes" "Default Deny NetworkPolicy" "PASS" "default-deny-all present"
else
  add_result "Kubernetes" "Default Deny NetworkPolicy" "FAIL" "default-deny-all missing"
fi

if kubectl get statefulset securerag-vault -n vault >/dev/null 2>&1; then
  ready=$(kubectl get statefulset securerag-vault -n vault -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$ready" -gt 0 ]; then
    add_result "Kubernetes" "HashiCorp Vault running" "PASS" "Vault replicas: ${ready}"
  else
    add_result "Kubernetes" "HashiCorp Vault running" "FAIL" "Vault unhealthy"
  fi
else
  add_result "Kubernetes" "HashiCorp Vault running" "FAIL" "Vault statefulset not found"
fi

if kubectl get externalsecrets -n securerag-hub >/dev/null 2>&1; then
  es_reconciled=$(kubectl get externalsecrets -n securerag-hub -o json 2>/dev/null | jq '[.items[].status.conditions[]? | select(.type=="Ready" and .status=="True")] | length' 2>/dev/null || echo "0")
  es_total=$(kubectl get externalsecrets -n securerag-hub -o json 2>/dev/null | jq '.items | length' 2>/dev/null || echo "0")
  if [ "$es_reconciled" -eq "$es_total" ] && [ "$es_total" -gt 0 ]; then
    add_result "Kubernetes" "External Secrets Reconciled" "PASS" "Reconciled: ${es_reconciled}/${es_total}"
  else
    add_result "Kubernetes" "External Secrets Reconciled" "FAIL" "Reconciled: ${es_reconciled}/${es_total}"
  fi
else
  add_result "Kubernetes" "External Secrets Reconciled" "FAIL" "No ExternalSecrets found"
fi

# --- 6. OBSERVABILITY STACK ---
if kubectl get deployment prometheus -n securerag-monitoring >/dev/null 2>&1; then
  ready=$(kubectl get deployment prometheus -n securerag-monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$ready" -gt 0 ]; then
    add_result "Observability" "Prometheus Server" "PASS" "Prometheus running"
  else
    add_result "Observability" "Prometheus Server" "FAIL" "Prometheus unhealthy"
  fi
else
  add_result "Observability" "Prometheus Server" "FAIL" "Prometheus deployment not found"
fi

if kubectl get deployment loki -n securerag-monitoring >/dev/null 2>&1; then
  ready=$(kubectl get deployment loki -n securerag-monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$ready" -gt 0 ]; then
    add_result "Observability" "Loki Log Aggregator" "PASS" "Loki running"
  else
    add_result "Observability" "Loki Log Aggregator" "FAIL" "Loki unhealthy"
  fi
else
  add_result "Observability" "Loki Log Aggregator" "FAIL" "Loki deployment not found"
fi

if kubectl get deployment grafana -n securerag-monitoring >/dev/null 2>&1; then
  ready=$(kubectl get deployment grafana -n securerag-monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$ready" -gt 0 ]; then
    add_result "Observability" "Grafana Dashboards" "PASS" "Grafana running"
  else
    add_result "Observability" "Grafana Dashboards" "FAIL" "Grafana unhealthy"
  fi
else
  add_result "Observability" "Grafana Dashboards" "FAIL" "Grafana deployment not found"
fi

if kubectl get deployment tempo -n securerag-monitoring >/dev/null 2>&1; then
  ready=$(kubectl get deployment tempo -n securerag-monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$ready" -gt 0 ]; then
    add_result "Observability" "Tempo Tracing" "PASS" "Tempo running"
  else
    add_result "Observability" "Tempo Tracing" "FAIL" "Tempo unhealthy"
  fi
else
  add_result "Observability" "Tempo Tracing" "FAIL" "Tempo deployment not found"
fi

# Calculate Global Score
SCORE=$(( (CHECKS_PASSED * 100) / CHECKS_EXECUTED ))
LEVEL="Low Compliance"
if [ "$SCORE" -eq 100 ]; then
  LEVEL="Elite / SOC2 Compliant"
elif [ "$SCORE" -ge 90 ]; then
  LEVEL="High Compliance"
elif [ "$SCORE" -ge 70 ]; then
  LEVEL="Medium Compliance"
fi

# Render final report to file
{
  echo "# SecureRAG Hub - Global Compliance Verification Report"
  echo
  echo "Generated at UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`"
  echo
  echo "## Summary Dashboard"
  echo "| Metric | Value |"
  echo "| --- | --- |"
  echo "| Checks Executed | **${CHECKS_EXECUTED}** |"
  echo "| Checks Passed | **${CHECKS_PASSED}** |"
  echo "| Checks Failed | **${CHECKS_FAILED}** |"
  echo "| Compliance Level | **${LEVEL}** |"
  echo "| **Global Score** | **${SCORE}%** |"
  echo
  echo "## Verification Details"
  echo "| Component | Control Name | Status | Details |"
  echo "| --- | --- | --- | --- |"
  printf "${RESULTS}"
} > "${REPORT_FILE}"

echo
echo "=========================================================="
echo "          GLOBAL COMPLIANCE VERIFICATION SUMMARY"
echo "=========================================================="
echo "  Checks Executed : ${CHECKS_EXECUTED}"
echo "  Checks Passed   : ${CHECKS_PASSED}"
echo "  Checks Failed   : ${CHECKS_FAILED}"
echo "  Compliance Level: ${LEVEL}"
echo "  Global Score    : ${SCORE}%"
echo "=========================================================="
echo "  Report written to: ${REPORT_FILE}"
echo "=========================================================="

if [ "${CHECKS_FAILED}" -gt 0 ]; then
  exit 1
fi
