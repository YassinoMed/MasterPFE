#!/usr/bin/env bash
# validate-k8s-hardening.sh — Verify Kubernetes workloads and namespace hardening status
set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-reports/postdeploy}"
REPORT_FILE="${REPORT_DIR}/k8s-hardening-report.md"

mkdir -p "${REPORT_DIR}"

FAILURES=0
WARNINGS=0

pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1" >&2; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

official_deployments=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

{
  printf '# Kubernetes Hardening Report — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Cluster context: `%s`\n\n' "$(kubectl config current-context 2>/dev/null || printf 'unknown')"
} > "${REPORT_FILE}"

echo "## 1. Namespace-Level Hardening" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Check PSA restricted label
psa_restricted=$(kubectl get ns "${NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "missing")
if [[ "${psa_restricted}" == "restricted" ]]; then
  pass "Namespace ${NS} has Pod Security Admission set to Enforce: Restricted"
  printf -- '- **Pod Security Enforce**: `restricted` (✅ Compliant)\n' >> "${REPORT_FILE}"
else
  psa_audit=$(kubectl get ns "${NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || echo "missing")
  if [[ "${psa_audit}" == "restricted" ]]; then
    warn "Namespace ${NS} has Pod Security Admission set to Audit: Restricted"
    printf -- '- **Pod Security Enforce**: `missing` | **Audit**: `restricted` (⚠️ Warning: Target is Enforce)\n' >> "${REPORT_FILE}"
  else
    fail "Namespace ${NS} is missing Pod Security Admission Restricted labels"
    printf -- '- **Pod Security Enforce**: `missing` (❌ Non-Compliant)\n' >> "${REPORT_FILE}"
  fi
fi

# Check ResourceQuota
if kubectl get resourcequota -n "${NS}" >/dev/null 2>&1; then
  pass "ResourceQuota exists in namespace ${NS}"
  printf -- '- **ResourceQuota**: `Active` (✅ Compliant)\n' >> "${REPORT_FILE}"
else
  warn "No ResourceQuota found in namespace ${NS}"
  printf -- '- **ResourceQuota**: `Missing` (⚠️ Warning)\n' >> "${REPORT_FILE}"
fi

# Check LimitRange
if kubectl get limitrange -n "${NS}" >/dev/null 2>&1; then
  pass "LimitRange exists in namespace ${NS}"
  printf -- '- **LimitRange**: `Active` (✅ Compliant)\n\n' >> "${REPORT_FILE}"
else
  warn "No LimitRange found in namespace ${NS}"
  printf -- '- **LimitRange**: `Missing` (⚠️ Warning)\n\n' >> "${REPORT_FILE}"
fi

echo "## 2. Workload Hardening Checks" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "| Workload | ServiceAccount | NonRoot | ReadOnlyFS | NoPrivEsc | Drop Caps | Seccomp | Probes (L/R/S) | Resources (Req/Lim) | Status |" >> "${REPORT_FILE}"
echo "|---|---|---|---|---|---|---|---|---|---|" >> "${REPORT_FILE}"

for deploy in "${official_deployments[@]}"; do
  if ! kubectl get deployment "${deploy}" -n "${NS}" > /dev/null 2>&1; then
    fail "Deployment ${deploy} does not exist"
    echo "| \`${deploy}\` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ FAILED |" >> "${REPORT_FILE}"
    continue
  fi

  # ServiceAccount Check
  sa=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null || echo "default")
  sa_ok="❌"
  if [[ "${sa}" == "sa-${deploy}" ]]; then
    sa_ok="✅"
    # ServiceAccount automount check
    automount=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.automountServiceAccountToken}' 2>/dev/null || echo "true")
    if [[ "${automount}" == "false" ]]; then
      sa_ok="✅ (no-token)"
    fi
  fi

  # Pod runAsNonRoot
  non_root=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null || echo "false")
  non_root_ok="❌"
  [[ "${non_root}" == "true" ]] && non_root_ok="✅"

  # Container checks
  readonly_fs=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null || echo "false")
  readonly_fs_ok="❌"
  [[ "${readonly_fs}" == "true" ]] && readonly_fs_ok="✅"

  priv_escalation=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null || echo "true")
  priv_escalation_ok="❌"
  [[ "${priv_escalation}" == "false" ]] && priv_escalation_ok="✅"

  drop_caps=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop[*]}' 2>/dev/null || echo "none")
  drop_caps_ok="❌"
  [[ "${drop_caps}" =~ "ALL" ]] && drop_caps_ok="✅"

  seccomp=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}' 2>/dev/null || echo "none")
  seccomp_ok="❌"
  [[ "${seccomp}" == "RuntimeDefault" ]] && seccomp_ok="✅"

  # Probes (Liveness, Readiness, Startup)
  liveness=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' 2>/dev/null || echo "")
  readiness=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null || echo "")
  startup=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].startupProbe}' 2>/dev/null || echo "")
  
  probes_desc=""
  [[ -n "${liveness}" ]] && probes_desc="${probes_desc}L" || probes_desc="${probes_desc}-"
  [[ -n "${readiness}" ]] && probes_desc="${probes_desc}R" || probes_desc="${probes_desc}-"
  [[ -n "${startup}" ]] && probes_desc="${probes_desc}S" || probes_desc="${probes_desc}-"

  # Resources Requests/Limits
  cpu_req=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
  mem_req=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
  cpu_lim=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
  mem_lim=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
  
  resources_ok="❌"
  if [[ -n "${cpu_req}" && -n "${mem_req}" && -n "${cpu_lim}" && -n "${mem_lim}" ]]; then
    resources_ok="✅"
  fi

  # Overall Workload Status
  w_status="✅ OK"
  if [[ "${sa_ok}" =~ "❌" || "${non_root_ok}" == "❌" || "${readonly_fs_ok}" == "❌" || "${priv_escalation_ok}" == "❌" || "${drop_caps_ok}" == "❌" || "${seccomp_ok}" == "❌" || "${resources_ok}" == "❌" ]]; then
    w_status="❌ FAIL"
    fail "Workload ${deploy} has hardening gaps"
  else
    pass "Workload ${deploy} is fully hardened"
  fi

  echo "| \`${deploy}\` | ${sa_ok} | ${non_root_ok} | ${readonly_fs_ok} | ${priv_escalation_ok} | ${drop_caps_ok} | ${seccomp_ok} | \`${probes_desc}\` | ${resources_ok} | ${w_status} |" >> "${REPORT_FILE}"
done
echo "" >> "${REPORT_FILE}"

echo "## 3. Network-Level Isolation" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# NetworkPolicy default-deny
default_deny=$(kubectl get networkpolicy default-deny-all -n "${NS}" >/dev/null 2>&1 && echo "true" || echo "false")
if [[ "${default_deny}" == "true" ]]; then
  pass "Default-deny NetworkPolicy exists"
  printf -- '- **Default-Deny Policy**: `Active` (✅ Compliant)\n' >> "${REPORT_FILE}"
else
  fail "Default-deny NetworkPolicy is missing"
  printf -- '- **Default-Deny Policy**: `Missing` (❌ Non-Compliant)\n' >> "${REPORT_FILE}"
fi

# PodDisruptionBudget check
pdbs=$(kubectl get pdb -n "${NS}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "${pdbs}" -gt 0 ]]; then
  pass "${pdbs} PodDisruptionBudget(s) found"
  printf -- '- **PodDisruptionBudget**: `Active` (%d configured) (✅ Compliant)\n\n' "${pdbs}" >> "${REPORT_FILE}"
else
  warn "No PodDisruptionBudgets configured"
  printf -- '- **PodDisruptionBudget**: `None` (⚠️ Warning: Recommended for high availability)\n\n' >> "${REPORT_FILE}"
fi

echo "## 4. Summary" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
if [[ "${FAILURES}" -eq 0 ]]; then
  printf -- '- **Status**: `OK` (%d warnings)\n' "${WARNINGS}" >> "${REPORT_FILE}"
  printf -- '- **Hardening compliance**: `100%%` of critical checks passed\n' >> "${REPORT_FILE}"
else
  printf -- '- **Status**: `FAILED` (%d failures, %d warnings)\n' "${FAILURES}" "${WARNINGS}" >> "${REPORT_FILE}"
fi

printf '[INFO] Hardening report generated at: %s\n' "${REPORT_FILE}"

if [[ "${FAILURES}" -gt 0 ]]; then
  exit 1
fi
