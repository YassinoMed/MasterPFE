#!/usr/bin/env bash
# chaos-smoke-test.sh — SecureRAG Hub Chaos Smoke Test
# Runs all chaos experiments in sequence, validates SLO compliance,
# measures RTO, and generates a report.
#
# Usage: NAMESPACE=securerag-hub bash scripts/chaos/chaos-smoke-test.sh
#
# Dependencies: kubectl, curl, bc, jq

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
CHAOS_NAMESPACE="${CHAOS_NAMESPACE:-securerag-chaos}"
PROBE_INTERVAL="${PROBE_INTERVAL:-2}"
SLO_AVAILABILITY="${SLO_AVAILABILITY:-99.5}"
SLO_RTO_SECONDS="${SLO_RTO_SECONDS:-60}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="artifacts/chaos"
mkdir -p "${REPORT_DIR}"
REPORT="${REPORT_DIR}/chaos-smoke-${TS}.md"
LOG="${REPORT_DIR}/chaos-smoke-${TS}.log"

exec > >(tee -a "${LOG}") 2>&1

require() { command -v "$1" >/dev/null 2>&1 || { echo "[FATAL] missing $1" >&2; exit 2; }; }
require kubectl require curl require bc require jq

echo "========================================================================"
echo "  SecureRAG Hub — Chaos Smoke Test"
echo "  Started:     $(date -u)"
echo "  Namespace:   ${NAMESPACE}"
echo "  SLO Avail:   ${SLO_AVAILABILITY}%"
echo "  SLO RTO:     ${SLO_RTO_SECONDS}s"
echo "  Report:      ${REPORT}"
echo "========================================================================"

pre_check() {
  echo ""
  echo "--- Pre-check ---"
  local missing=0
  for deploy in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
    local ready
    ready=$(kubectl -n "${NAMESPACE}" get deploy "${deploy}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "${ready}" -lt 1 ]]; then
      echo "  [FAIL] ${deploy}: 0 ready replicas"
      missing=$((missing + 1))
    else
      echo "  [OK]   ${deploy}: ${ready} ready"
    fi
  done
  return "${missing}"
}

probe_loop() {
  local url="$1" duration="$2" label="$3"
  local total=0 ok=0 fail=0
  local end
  end=$(( $(date +%s) + duration ))
  while [ "$(date +%s)" -lt "${end}" ]; do
    total=$((total + 1))
    if curl -fsS --max-time 3 "${url}" >/dev/null 2>&1; then
      ok=$((ok + 1))
      echo "  [PROBE] ${label}: OK"
    else
      fail=$((fail + 1))
      echo "  [PROBE] ${label}: FAIL"
    fi
    sleep "${PROBE_INTERVAL}"
  done
  echo "PROBE_RESULT:${label}:total=${total}:ok=${ok}:fail=${fail}"
}

measure_rto() {
  local deploy="$1"
  local start end
  start=$(date +%s)
  kubectl -n "${NAMESPACE}" rollout status "deploy/${deploy}" --timeout=120s >/dev/null 2>&1 || true
  end=$(date +%s)
  echo $((end - start))
}

run_experiment() {
  local name="$1" deploy="$2" chaos_yaml="$3" probe_url="$4" probe_duration="$5"
  echo ""
  echo "============================================"
  echo "  Experiment: ${name}"
  echo "  Target:     ${deploy}"
  echo "  Chaos CR:   ${chaos_yaml}"
  echo "============================================"

  # Start probe in background
  probe_loop "${probe_url}" "${probe_duration}" "${name}" &
  local probe_pid=$!

  # Apply chaos
  kubectl apply -f "${chaos_yaml}" -n "${NAMESPACE}"

  # Wait for experiment duration + buffer
  sleep "$((probe_duration + 5))"

  # Delete chaos resource to stop experiment
  kubectl delete -f "${chaos_yaml}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true

  # Wait for probe to finish
  wait "${probe_pid}" || true

  # Extract probe results from last line
  local probe_line
  probe_line=$(grep '^PROBE_RESULT:' "${LOG}" | tail -1)
  local total ok fail
  total=$(echo "${probe_line}" | cut -d: -f4 | cut -d= -f2)
  ok=$(echo "${probe_line}" | cut -d: -f5 | cut -d= -f2)
  fail=$(echo "${probe_line}" | cut -d: -f6 | cut -d= -f2)
  total=${total:-0}; ok=${ok:-0}; fail=${fail:-0}

  local availability=100.0
  if [ "${total}" -gt 0 ]; then
    availability=$(echo "scale=2; 100 * ${ok} / ${total}" | bc)
  fi

  local rto=0
  rto=$(measure_rto "${deploy}")
  local slo_pass="PASS"
  local avail_pass="PASS"
  if [ "${rto}" -gt "${SLO_RTO_SECONDS}" ]; then
    slo_pass="FAIL"
  fi
  if (( $(echo "${availability} < ${SLO_AVAILABILITY}" | bc -l) )); then
    avail_pass="FAIL"
  fi

  echo ""
  echo "  Results for ${name}:"
  echo "    Availability: ${availability}% (${ok}/${total}) — ${avail_pass}"
  echo "    RTO:          ${rto}s — ${slo_pass}"

  # Record for report
  echo "RESULT:${name}:availability=${availability}:rto=${rto}:slo=${slo_pass}:avail=${avail_pass}" >> "${REPORT}"
}

# Pre-check
pre_check || { echo "[FATAL] Pre-check failed"; exit 1; }

# Service probe URLs — must match actual service endpoints
# These should be reachable via port-forward or ingress
BASE_URL="${PROBE_BASE_URL:-http://localhost:8000}"

# Run experiments
run_experiment "pod-kill-portal-web" "portal-web" \
  "infra/k8s/chaos/experiments/pod-kill.yaml" \
  "${BASE_URL}/health" 35

run_experiment "network-latency-chatbot" "chatbot-manager" \
  "infra/k8s/chaos/experiments/network-latency.yaml" \
  "${BASE_URL}/api/chat/health" 35

run_experiment "cpu-stress-portal-web" "portal-web" \
  "infra/k8s/chaos/experiments/pod-cpu-stress.yaml" \
  "${BASE_URL}/health" 35

run_experiment "memory-stress-conversation" "conversation-service" \
  "infra/k8s/chaos/experiments/pod-memory-stress.yaml" \
  "${BASE_URL}/api/conversation/health" 35

run_experiment "dns-failure-api-gateway" "api-gateway" \
  "infra/k8s/chaos/experiments/dns-failure.yaml" \
  "${BASE_URL}/health" 35

run_experiment "postgres-outage" "postgres-auth" \
  "infra/k8s/chaos/experiments/postgres-outage.yaml" \
  "${BASE_URL}/api/auth/health" 35

# Aggregate results
echo ""
echo "========================================================================"
echo "  Aggregating Results"
echo "========================================================================"

total_slo_pass=0
total_experiments=0
overall_verdict="PASS"

while IFS=: read -r _ name avail_str rto_str slo_str avail_str2; do
  total_experiments=$((total_experiments + 1))
  local avail_val="${avail_str#availability=}"
  local rto_val="${rto_str#rto=}"
  local slo_val="${slo_str#slo=}"
  local avail_val2="${avail_str2#avail=}"
  if [ "${slo_val}" = "PASS" ] && [ "${avail_val2}" = "PASS" ]; then
    total_slo_pass=$((total_slo_pass + 1))
  fi
done < <(grep '^RESULT:' "${REPORT}" 2>/dev/null || echo "")

if [ "${total_experiments}" -gt 0 ] && [ "${total_slo_pass}" -lt "${total_experiments}" ]; then
  overall_verdict="DEGRADED"
fi

# Generate final report
{
  echo "# Chaos Smoke Test Report"
  echo ""
  echo "_Generated: $(date -u)_"
  echo "_Namespace: ${NAMESPACE}_"
  echo ""
  echo "## Summary"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|-------|"
  echo "| Experiments Run | ${total_experiments} |"
  echo "| SLO Passed | ${total_slo_pass}/${total_experiments} |"
  echo "| Availability SLO | ${SLO_AVAILABILITY}% |"
  echo "| RTO SLO | ${SLO_RTO_SECONDS}s |"
  echo "| Overall Verdict | **${overall_verdict}** |"
  echo ""
  echo "## Per-Experiment Results"
  echo ""
  echo "| Experiment | Availability | RTO (s) | SLO | Avail |"
  echo "|------------|-------------|---------|-----|-------|"
  grep '^RESULT:' "${REPORT}" 2>/dev/null | while IFS=: read -r _ name avail_str rto_str slo_str avail_str2; do
    local avail_val="${avail_str#availability=}"
    local rto_val="${rto_str#rto=}"
    local slo_val="${slo_str#slo=}"
    local avail_val2="${avail_str2#avail=}"
    echo "| ${name} | ${avail_val}% | ${rto_val} | ${slo_val} | ${avail_val2} |"
  done
  echo ""
  echo "## Logs"
  echo ""
  echo "Full log: \`${LOG}\`"
  echo ""
} > "${REPORT}"

echo ""
echo "========================================================================"
echo "  Chaos Smoke Test Complete"
echo "  Verdict: ${overall_verdict}"
echo "  Report:  ${REPORT}"
echo "========================================================================"

if [ "${overall_verdict}" = "DEGRADED" ]; then
  exit 1
fi
