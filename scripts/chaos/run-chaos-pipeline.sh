#!/usr/bin/env bash
# run-chaos-pipeline.sh — SecureRAG Hub Chaos Pipeline
# Designed for Jenkins CI/CD integration.
# Runs experiments, validates results, and gates on SLO compliance.
#
# Usage:
#   bash scripts/chaos/run-chaos-pipeline.sh              # run full pipeline
#   bash scripts/chaos/run-chaos-pipeline.sh --validate     # validate existing results only
#   bash scripts/chaos/run-chaos-pipeline.sh --cleanup      # remove chaos resources
#
# Environment:
#   NAMESPACE          — target namespace (default: securerag-hub)
#   CHAOS_NAMESPACE    — chaos system namespace (default: securerag-chaos)
#   SLO_RTO            — RTO threshold in seconds (default: 60)
#   SLO_AVAIL          — availability threshold percent (default: 99.5)
#   DRY_RUN            — set to "true" to skip actual chaos (default: false)
#   JENKINS_URL        — Jenkins job URL (optional, for reporting)
#   BUILD_NUMBER       — Jenkins build number (optional)
#   REPORT_DIR         — output directory (default: artifacts/chaos)
#   SLACK_WEBHOOK_URL  — optional slack notification URL

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
CHAOS_NAMESPACE="${CHAOS_NAMESPACE:-securerag-chaos}"
SLO_RTO="${SLO_RTO:-60}"
SLO_AVAIL="${SLO_AVAIL:-99.5}"
DRY_RUN="${DRY_RUN:-false}"
REPORT_DIR="${REPORT_DIR:-artifacts/chaos}"
JENKINS_URL="${JENKINS_URL:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
STAGE_LOG="${REPORT_DIR}/pipeline-${TS}.log"
mkdir -p "${REPORT_DIR}"

exec > >(tee -a "${STAGE_LOG}") 2>&1

require() { command -v "$1" >/dev/null 2>&1 || { echo "[FATAL] missing $1" >&2; exit 2; }; }
require kubectl require curl require bc require jq

echo "========================================================================"
echo "  SecureRAG Hub — Chaos Pipeline"
echo "  Build:       ${JENKINS_URL:-local} ${BUILD_NUMBER:+ #${BUILD_NUMBER}}"
echo "  Namespace:   ${NAMESPACE}"
echo "  SLO:         RTO ≤ ${SLO_RTO}s, Avail ≥ ${SLO_AVAIL}%"
echo "  DRY_RUN:     ${DRY_RUN}"
echo "  Started:     $(date -u)"
echo "========================================================================"

##############################
# Stage 0: Pre-flight checks #
##############################
pre_flight() {
  echo ""
  echo "--- [Stage 0] Pre-flight Checks ---"

  # Check cluster connectivity
  kubectl cluster-info --request-timeout=5s >/dev/null 2>&1 || { echo "[FATAL] Cannot reach cluster"; exit 1; }
  echo "  [OK] Cluster reachable"

  # Check target namespace
  kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || { echo "[FATAL] Namespace ${NAMESPACE} not found"; exit 1; }
  echo "  [OK] Namespace ${NAMESPACE} exists"

  # Check key deployments
  local required_deploys=("portal-web" "auth-users" "chatbot-manager" "conversation-service" "audit-security-service")
  for deploy in "${required_deploys[@]}"; do
    local ready
    ready=$(kubectl -n "${NAMESPACE}" get deploy "${deploy}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "${ready}" -lt 1 ]; then
      echo "  [FAIL] ${deploy}: 0 ready replicas"
      exit 1
    fi
    echo "  [OK]   ${deploy}: ${ready} ready"
  done

  # Check chaos namespace
  kubectl get ns "${CHAOS_NAMESPACE}" >/dev/null 2>&1 || { echo "  [WARN] Chaos namespace ${CHAOS_NAMESPACE} not found — will install"; }

  echo "  [OK] Pre-flight checks passed"
}

##############################
# Stage 1: Install Chaos Mesh #
##############################
install_chaos_mesh() {
  echo ""
  echo "--- [Stage 1] Install Chaos Mesh ---"

  if [ "${DRY_RUN}" = "true" ]; then
    echo "  [SKIP] DRY_RUN — would install Chaos Mesh operator"
    return 0
  fi

  # Create chaos namespace if needed
  kubectl get ns "${CHAOS_NAMESPACE}" >/dev/null 2>&1 || \
    kubectl create ns "${CHAOS_NAMESPACE}"

  # Apply operator manifests
  kubectl apply -k infra/k8s/chaos/ 2>/dev/null || \
    kubectl apply -f infra/k8s/chaos/namespace.yaml && \
    kubectl apply -f infra/k8s/chaos/operator-deployment.yaml

  # Wait for controller
  echo "  Waiting for chaos-mesh-controller-manager..."
  kubectl -n "${CHAOS_NAMESPACE}" rollout status deploy/chaos-mesh-controller-manager --timeout=120s

  # Wait for daemon set
  echo "  Waiting for chaos-daemon..."
  kubectl -n "${CHAOS_NAMESPACE}" rollout status daemonset/chaos-daemon --timeout=120s

  echo "  [OK] Chaos Mesh installed"
}

##############################
# Stage 2: Run Experiments   #
##############################
run_experiments() {
  echo ""
  echo "--- [Stage 2] Run Chaos Experiments ---"

  local experiments_dir="infra/k8s/chaos/experiments"
  local probe_url="${PROBE_BASE_URL:-http://localhost:8000}"

  # Map experiments to probe endpoints
  declare -A experiment_probes
  experiment_probes["pod-kill"]="${probe_url}/health"
  experiment_probes["network-latency"]="${probe_url}/api/chat/health"
  experiment_probes["pod-cpu-stress"]="${probe_url}/health"
  experiment_probes["pod-memory-stress"]="${probe_url}/api/conversation/health"
  experiment_probes["dns-failure"]="${probe_url}/health"
  experiment_probes["postgres-outage"]="${probe_url}/api/auth/health"

  local result_file="${REPORT_DIR}/pipeline-results-${TS}.txt"
  local overall_verdict="PASS"
  local pass_count=0
  local total_count=0

  for experiment_file in "${experiments_dir}"/*.yaml; do
    local exp_name
    exp_name=$(basename "${experiment_file}" .yaml)
    local probe_url="${experiment_probes[${exp_name}]:-${probe_url}/health}"
    total_count=$((total_count + 1))

    echo ""
    echo "  --- Experiment: ${exp_name} ---"
    echo "  File:  ${experiment_file}"
    echo "  Probe: ${probe_url}"

    if [ "${DRY_RUN}" = "true" ]; then
      echo "  [SKIP] DRY_RUN"
      echo "RESULT:${exp_name}:availability=100.0:rto=0:slo=PASS:avail=PASS" >> "${result_file}"
      pass_count=$((pass_count + 1))
      continue
    fi

    # Start probe in background
    local duration=35
    local total=0 ok=0 fail=0
    local end
    end=$(( $(date +%s) + duration ))

    # Apply chaos
    kubectl apply -f "${experiment_file}" -n "${NAMESPACE}" 2>/dev/null || \
      { echo "  [FAIL] Could not apply ${experiment_file}"; echo "RESULT:${exp_name}:availability=0:rto=999:slo=FAIL:avail=FAIL" >> "${result_file}"; continue; }

    # Probe loop
    while [ "$(date +%s)" -lt "${end}" ]; do
      total=$((total + 1))
      if curl -fsS --max-time 3 "${probe_url}" >/dev/null 2>&1; then
        ok=$((ok + 1))
      else
        fail=$((fail + 1))
        echo "  [PROBE FAIL] ${exp_name}"
      fi
      sleep 2
    done

    # Remove chaos
    kubectl delete -f "${experiment_file}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true

    # Measure RTO
    local deploy_name="${exp_name#pod-kill-}"
    deploy_name="${deploy_name#network-latency-}"
    deploy_name="${deploy_name#cpu-stress-}"
    deploy_name="${deploy_name#memory-stress-}"
    deploy_name="${deploy_name#dns-failure-}"
    deploy_name="${deploy_name#postgres-outage-}"
    deploy_name="${deploy_name:-portal-web}"

    local start_rto end_rto rto
    start_rto=$(date +%s)
    kubectl -n "${NAMESPACE}" rollout status "deploy/${deploy_name}" --timeout=120s >/dev/null 2>&1 || true
    end_rto=$(date +%s)
    rto=$((end_rto - start_rto))

    # Calculate availability
    local availability=100.0
    if [ "${total}" -gt 0 ]; then
      availability=$(echo "scale=2; 100 * ${ok} / ${total}" | bc)
    fi

    # Evaluate SLO
    local avail_slo="PASS"
    local rto_slo="PASS"
    if (( $(echo "${availability} < ${SLO_AVAIL}" | bc -l) )); then
      avail_slo="FAIL"
    fi
    if [ "${rto}" -gt "${SLO_RTO}" ]; then
      rto_slo="FAIL"
    fi

    if [ "${avail_slo}" = "PASS" ] && [ "${rto_slo}" = "PASS" ]; then
      pass_count=$((pass_count + 1))
    fi

    echo "  Availability: ${availability}% (${ok}/${total}) — ${avail_slo}"
    echo "  RTO:          ${rto}s — ${rto_slo}"
    echo "RESULT:${exp_name}:availability=${availability}:rto=${rto}:slo=${rto_slo}:avail=${avail_slo}" >> "${result_file}"
  done

  if [ "${pass_count}" -lt "${total_count}" ]; then
    overall_verdict="DEGRADED"
  fi

  echo ""
  echo "  Experiment Summary: ${pass_count}/${total_count} passed — ${overall_verdict}"
  echo "${overall_verdict}" > "${REPORT_DIR}/pipeline-verdict.txt"
}

##############################
# Stage 3: Validate Results   #
##############################
validate_results() {
  echo ""
  echo "--- [Stage 3: Validate SLO Compliance] ---"

  local result_file="${REPORT_DIR}/pipeline-results-${TS}.txt"
  if [ ! -f "${result_file}" ]; then
    # Try to find latest results
    result_file=$(ls -t "${REPORT_DIR}"/pipeline-results-*.txt 2>/dev/null | head -1 || echo "")
    if [ -z "${result_file}" ]; then
      echo "  [FAIL] No result files found"
      exit 1
    fi
  fi

  local total=0 passed=0 failed=0
  while IFS=: read -r _ name avail_str rto_str slo_str avail_str2; do
    total=$((total + 1))
    local slo="${slo_str#slo=}"
    local avail_flag="${avail_str2#avail=}"
    if [ "${slo}" = "PASS" ] && [ "${avail_flag}" = "PASS" ]; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
      echo "  [FAIL] ${name}: RTO=${slo}, Avail=${avail_flag}"
    fi
  done < <(grep '^RESULT:' "${result_file}" 2>/dev/null || true)

  echo "  Total:  ${total}"
  echo "  Passed: ${passed}"
  echo "  Failed: ${failed}"

  if [ "${failed}" -gt 0 ]; then
    echo "  [FAIL] SLO validation failed — gating deployment"
    exit 1
  fi
  echo "  [OK] All SLO thresholds met"
}

##############################
# Stage 4: Generate Report    #
##############################
generate_report() {
  echo ""
  echo "--- [Stage 4] Generate Report ---"

  local result_file="${REPORT_DIR}/pipeline-results-${TS}.txt"
  local report_file="${REPORT_DIR}/pipeline-report-${TS}.md"

  if [ ! -f "${result_file}" ]; then
    result_file=$(ls -t "${REPORT_DIR}"/pipeline-results-*.txt 2>/dev/null | head -1 || echo "")
  fi

  # Delegate to chaos-report.sh
  INPUT_DIR="${REPORT_DIR}" OUTPUT_FILE="${report_file}" \
    bash scripts/chaos/chaos-report.sh

  echo "  [OK] Report: ${report_file}"
}

##############################
# Stage 5: Notify             #
##############################
send_notification() {
  local verdict="$1"
  if [ -z "${SLACK_WEBHOOK_URL}" ]; then
    return 0
  fi

  echo ""
  echo "--- [Stage 5] Send Notification ---"

  local color
  if [ "${verdict}" = "PASS" ]; then
    color="good"
  else
    color="danger"
  fi

  local message
  message=$(cat <<PAYLOAD
{
  "attachments": [{
    "color": "${color}",
    "title": "Chaos Pipeline — ${verdict}",
    "text": "Namespace: ${NAMESPACE}\\nSLO: RTO ≤ ${SLO_RTO}s, Avail ≥ ${SLO_AVAIL}%\\nBuild: ${JENKINS_URL:-local} ${BUILD_NUMBER:+ #${BUILD_NUMBER}}\\nReport: ${REPORT_DIR}",
    "ts": $(date +%s)
  }]
}
PAYLOAD
)

  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d "${message}" "${SLACK_WEBHOOK_URL}" >/dev/null 2>&1 || echo "  [WARN] Slack notification failed"
  echo "  [OK] Notification sent"
}

##############################
# Stage 6: Cleanup            #
##############################
cleanup() {
  echo ""
  echo "--- [Stage 6] Cleanup ---"

  if [ "${DRY_RUN}" = "true" ]; then
    echo "  [SKIP] DRY_RUN"
    return 0
  fi

  # Remove chaos experiments
  local experiments_dir="infra/k8s/chaos/experiments"
  for f in "${experiments_dir}"/*.yaml; do
    kubectl delete -f "${f}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true
    echo "  [OK] Removed $(basename "${f}")"
  done

  # Optionally uninstall Chaos Mesh (commented out for reuse)
  # kubectl delete -f infra/k8s/chaos/operator-deployment.yaml 2>/dev/null || true
  # kubectl delete ns "${CHAOS_NAMESPACE}" --ignore-not-found 2>/dev/null || true
  # echo "  [OK] Chaos Mesh uninstalled"

  echo "  [OK] Cleanup complete"
}

##############################
# Main                        #
##############################

MODE="${1:-full}"

case "${MODE}" in
  --validate)
    pre_flight
    validate_results
    generate_report
    ;;
  --cleanup)
    cleanup
    ;;
  --notify)
    local v
    v=$(cat "${REPORT_DIR}/pipeline-verdict.txt" 2>/dev/null || echo "UNKNOWN")
    send_notification "${v}"
    ;;
  full|*)
    pre_flight
    install_chaos_mesh
    run_experiments
    validate_results
    generate_report

    local verdict
    verdict=$(cat "${REPORT_DIR}/pipeline-verdict.txt" 2>/dev/null || echo "DEGRADED")
    send_notification "${verdict}"
    cleanup

    echo ""
    echo "========================================================================"
    echo "  Pipeline Complete — Verdict: ${verdict}"
    echo "========================================================================"

    if [ "${verdict}" = "DEGRADED" ]; then
      exit 1
    fi
    ;;
esac
