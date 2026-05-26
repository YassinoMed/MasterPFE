#!/usr/bin/env bash
# validate-rollout.sh — Verify Kubernetes rollout health post-deployment
set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_DIR}/rollout-validation.md"

mkdir -p "${REPORT_DIR}"

pass() { printf '[PASS] %s\n' "$1" | tee -a "${REPORT_FILE}"; }
warn() { printf '[WARN] %s\n' "$1" | tee -a "${REPORT_FILE}"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '[FAIL] %s\n' "$1" | tee -a "${REPORT_FILE}"; FAILURES=$((FAILURES + 1)); }

FAILURES=0
WARNINGS=0

official_deployments=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

{
  printf '# Rollout Validation Report — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Cluster context: `%s`\n\n' "$(kubectl config current-context 2>/dev/null || printf 'unknown')"
} > "${REPORT_FILE}"

# ── 1. Namespace existence ──────────────────────────────────────────────
echo "## 1. Namespace" >> "${REPORT_FILE}"
if kubectl get namespace "${NS}" > /dev/null 2>&1; then
  pass "Namespace ${NS} exists"
else
  fail "Namespace ${NS} does not exist"
  echo "" >> "${REPORT_FILE}"
  printf '\n**CRITICAL**: Namespace missing — cannot continue.\n' >> "${REPORT_FILE}"
  exit 1
fi
echo "" >> "${REPORT_FILE}"

# ── 2. Deployments existence and rollout status ─────────────────────────
echo "## 2. Deployments" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "| Deployment | Exists | Rollout OK | Desired | Ready | Up-to-date |" >> "${REPORT_FILE}"
echo "|---|---|---|---|---|---|" >> "${REPORT_FILE}"

for deploy in "${official_deployments[@]}"; do
  if ! kubectl get deployment "${deploy}" -n "${NS}" > /dev/null 2>&1; then
    fail "Deployment ${deploy} does not exist"
    echo "| \`${deploy}\` | ❌ | — | — | — | — |" >> "${REPORT_FILE}"
    continue
  fi

  desired=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.spec.replicas}')
  ready=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  ready="${ready:-0}"
  uptodate=$(kubectl get deployment "${deploy}" -n "${NS}" -o jsonpath='{.status.updatedReplicas}' 2>/dev/null || echo "0")
  uptodate="${uptodate:-0}"

  if kubectl rollout status "deployment/${deploy}" -n "${NS}" --timeout=120s > /dev/null 2>&1; then
    rollout_ok="✅"
    pass "Deployment ${deploy} rollout OK (${ready}/${desired} ready)"
  else
    rollout_ok="❌"
    fail "Deployment ${deploy} rollout FAILED"
  fi

  echo "| \`${deploy}\` | ✅ | ${rollout_ok} | ${desired} | ${ready} | ${uptodate} |" >> "${REPORT_FILE}"
done
echo "" >> "${REPORT_FILE}"

# ── 3. Pod health checks ────────────────────────────────────────────────
echo "## 3. Pod Health" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

crash_loop=$(kubectl get pods -n "${NS}" --field-selector=status.phase!=Succeeded \
  -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.state.waiting.reason}{"\n"}{end}{end}' 2>/dev/null \
  | grep -c "CrashLoopBackOff" || true)

image_pull=$(kubectl get pods -n "${NS}" --field-selector=status.phase!=Succeeded \
  -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.state.waiting.reason}{"\n"}{end}{end}' 2>/dev/null \
  | grep -c "ImagePullBackOff" || true)

if [[ "${crash_loop}" -gt 0 ]]; then
  fail "${crash_loop} pod(s) in CrashLoopBackOff"
else
  pass "No pods in CrashLoopBackOff"
fi

if [[ "${image_pull}" -gt 0 ]]; then
  fail "${image_pull} pod(s) in ImagePullBackOff"
else
  pass "No pods in ImagePullBackOff"
fi

pending=$(kubectl get pods -n "${NS}" --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "${pending}" -gt 0 ]]; then
  warn "${pending} pod(s) still Pending"
else
  pass "No pods Pending"
fi

running=$(kubectl get pods -n "${NS}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
pass "${running} pod(s) Running"
echo "" >> "${REPORT_FILE}"

# ── 4. Services and endpoints ───────────────────────────────────────────
echo "## 4. Services and Endpoints" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

for svc in "${official_deployments[@]}"; do
  if kubectl get svc "${svc}" -n "${NS}" > /dev/null 2>&1; then
    endpoints=$(kubectl get endpoints "${svc}" -n "${NS}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    if [[ -n "${endpoints}" ]]; then
      pass "Service ${svc} has active endpoints"
    else
      warn "Service ${svc} exists but has no ready endpoints"
    fi
  else
    fail "Service ${svc} does not exist"
  fi
done
echo "" >> "${REPORT_FILE}"

# ── 5. Recent events ───────────────────────────────────────────────────
echo "## 5. Recent Events (last 10)" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo '```text' >> "${REPORT_FILE}"
kubectl get events -n "${NS}" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 >> "${REPORT_FILE}" || true
echo '```' >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# ── Summary ─────────────────────────────────────────────────────────────
echo "## Summary" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
if [[ "${FAILURES}" -eq 0 ]]; then
  status="OK"
  printf -- '- **Status**: `OK` (%d warnings)\n' "${WARNINGS}" >> "${REPORT_FILE}"
  pass "Rollout validation completed: ${FAILURES} failures, ${WARNINGS} warnings"
else
  status="FAILED"
  printf -- '- **Status**: `FAILED` (%d failures, %d warnings)\n' "${FAILURES}" "${WARNINGS}" >> "${REPORT_FILE}"
fi

printf '[INFO] Rollout validation report: %s\n' "${REPORT_FILE}"

if [[ "${FAILURES}" -gt 0 ]]; then
  exit 1
fi
