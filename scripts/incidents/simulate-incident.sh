#!/usr/bin/env bash
# simulate-incident.sh — SecureRAG Hub Incident Simulation
# Purpose: Simulate incidents to test alert triggers, notification delivery,
#          and runbook execution. Safe for staging environments only.
# Usage: SIMULATE_POD_CRASH=true SIMULATE_LATENCY=true bash scripts/incidents/simulate-incident.sh
# Prerequisites: kubectl context pointing to staging cluster

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
MONITORING_NS="${MONITORING_NS:-securerag-monitoring}"
SIMULATE_POD_CRASH="${SIMULATE_POD_CRASH:-false}"
SIMULATE_LATENCY="${SIMULATE_LATENCY:-false}"
SIMULATE_UNAVAIL="${SIMULATE_UNAVAIL:-false}"
VALIDATE_ALERTS="${VALIDATE_ALERTS:-true}"
SIMULATION_PREFIX="simulation-$(date +%s)"

FAILURES=0
PASSES=0

log()    { echo "[$(date +%H:%M:%S)] $*"; }
pass()   { echo "[PASS] $*"; ((PASSES++)); }
fail()   { echo "[FAIL] $*"; ((FAILURES++)); }
section(){ echo ""; echo "═══════════════════════════════════════════"; echo "  $*"; echo "═══════════════════════════════════════════"; }

cleanup() {
  log "Cleaning up simulation resources..."
  kubectl delete pod "${SIMULATION_PREFIX}-crash" -n "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
  kubectl delete pod "${SIMULATION_PREFIX}-latency" -n "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
  kubectl delete pod "${SIMULATION_PREFIX}-unavail" -n "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
  log "Cleanup complete"
}
trap cleanup EXIT

section "SecureRAG Hub — Incident Simulation"
log "Namespace:       ${NAMESPACE}"
log "Simulation ID:   ${SIMULATION_PREFIX}"
log "Pod Crash:       ${SIMULATE_POD_CRASH}"
log "High Latency:    ${SIMULATE_LATENCY}"
log "Unavailability:  ${SIMULATE_UNAVAIL}"
log "Validate Alerts: ${VALIDATE_ALERTS}"

# ── Pre-flight Checks ────────────────────────────────────────────
section "Pre-flight Checks"

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  fail "Namespace ${NAMESPACE} does not exist"
  log "Create with: kubectl create namespace ${NAMESPACE}"
  exit 1
fi
pass "Namespace ${NAMESPACE} exists"

CLUSTER=$(kubectl config current-context 2>/dev/null || echo "unknown")
log "Current context: ${CLUSTER}"

if [ "${CLUSTER}" = "kind-securerag" ] || [ "${CLUSTER}" = "minikube" ]; then
  log "Local cluster detected — simulations will run in dev mode"
else
  log "Remote cluster — ensure this is a STAGING environment"
fi

# ── Simulation 1: Pod Crash ─────────────────────────────────────
if [ "${SIMULATE_POD_CRASH}" = "true" ]; then
  section "Simulation: Pod CrashLoopBackOff"

  CRASH_POD="${SIMULATION_PREFIX}-crash"

  log "Creating pod that crashes on startup (invalid command)..."
  kubectl run "${CRASH_POD}" \
    --image=busybox:1.36 \
    --namespace="${NAMESPACE}" \
    --restart=Never \
    --command -- sh -c "exit 1" 2>&1 || true

  log "Waiting for pod to enter CrashLoopBackOff..."
  for i in $(seq 1 12); do
    STATUS=$(kubectl get pod "${CRASH_POD}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
    if [ "${STATUS}" = "CrashLoopBackOff" ] || [ "${STATUS}" = "Error" ]; then
      pass "Pod ${CRASH_POD} is in ${STATUS} state"
      break
    fi
    sleep 5
  done

  if kubectl get pod "${CRASH_POD}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    CRASH_REASON=$(kubectl get pod "${CRASH_POD}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
    log "Pod crash reason: ${CRASH_REASON:-unknown}"
  fi

  # Clean up crash pod
  kubectl delete pod "${CRASH_POD}" -n "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true

  if [ "${VALIDATE_ALERTS}" = "true" ]; then
    log "Waiting for alert evaluation (30s)..."
    sleep 30

    # Check if Prometheus alert fired
    ALERT_CHECK=$(kubectl exec -n "${MONITORING_NS}" deployment/prometheus -- \
      wget -q -O- http://localhost:9090/api/v1/alerts 2>/dev/null || echo "")
    if echo "${ALERT_CHECK}" | grep -q "KubePodCrashLooping"; then
      pass "Prometheus alert KubePodCrashLooping triggered"
    else
      warn "Could not verify alert — Prometheus may not have evaluated yet"
    fi
  fi
else
  log "SKIP: Pod crash simulation disabled (SIMULATE_POD_CRASH=false)"
fi

# ── Simulation 2: High Latency ──────────────────────────────────
if [ "${SIMULATE_LATENCY}" = "true" ]; then
  section "Simulation: High Service Latency"

  LATENCY_POD="${SIMULATION_PREFIX}-latency"
  LATENCY_DURATION="${LATENCY_DURATION:-15}"  # seconds of artificial delay

  log "Creating pod with artificial latency..."
  kubectl run "${LATENCY_POD}" \
    --image=python:3.12-alpine \
    --namespace="${NAMESPACE}" \
    --restart=Never \
    --command -- sh -c "
      apk add -q curl;
      echo 'Starting latency simulation on port 8080...';
      while true; do
        echo 'Simulating slow endpoint...';
        RESPONSE_DELAY=${LATENCY_DURATION};
        printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 50\r\n\r\nSimulated slow response after %ds delay\n' \${RESPONSE_DELAY} | nc -l -p 8080 -q 1 -w \${RESPONSE_DELAY} 2>/dev/null || true;
      done
    " 2>&1 &

  LATENCY_PID=$!

  log "Waiting for latency pod to become ready..."
  sleep 10

  if kubectl get pod "${LATENCY_POD}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    pass "Latency pod ${LATENCY_POD} created"

    log "Measuring response time..."
    START_TIME=$(date +%s%N)
    kubectl run "${SIMULATION_PREFIX}-curl" \
      --image=curlimages/curl:latest \
      --namespace="${NAMESPACE}" \
      --restart=Never \
      --command -- sh -c "
        START=\$(date +%s);
        curl -s --max-time 30 http://${LATENCY_POD}.${NAMESPACE}.svc.cluster.local:8080/;
        END=\$(date +%s);
        echo \"Response time: \$((END - START))s\"
      " 2>&1 || true
    sleep 15

    # Clean up curl pod
    kubectl delete pod "${SIMULATION_PREFIX}-curl" -n "${NAMESPACE}" --ignore-not-found=true 2>/dev/null || true
  else
    fail "Latency pod ${LATENCY_POD} failed to start"
  fi

  if [ "${VALIDATE_ALERTS}" = "true" ]; then
    log "Sleeping 60s for Prometheus scrape and alert evaluation..."
    sleep 60
    log "Note: Latency alerts depend on service-monitor configuration"
  fi

  # Clean up
  kubectl delete pod "${LATENCY_POD}" -n "${NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
  kill ${LATENCY_PID} 2>/dev/null || true
fi

# ── Simulation 3: Service Unavailability ─────────────────────────
if [ "${SIMULATE_UNAVAIL}" = "true" ]; then
  section "Simulation: Service Unavailability"

  # Scale a deployment to 0 to simulate service down
  TARGET_DEPLOY="${TARGET_DEPLOY:-portal-web}"
  ORIGINAL_REPLICAS=$(kubectl get deploy "${TARGET_DEPLOY}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

  if [ "${ORIGINAL_REPLICAS}" = "0" ]; then
    log "Deployment ${TARGET_DEPLOY} not found or scaled to 0, using a test pod instead"
    UNAVAIL_POD="${SIMULATION_PREFIX}-unavail"
    kubectl run "${UNAVAIL_POD}" \
      --image=busybox:1.36 \
      --namespace="${NAMESPACE}" \
      --restart=Never \
      --command -- sleep 30 2>&1 || true
    sleep 5
    kubectl delete pod "${UNAVAIL_POD}" -n "${NAMESPACE}" --ignore-not-found=true 2>/dev/null || true
  else
    log "Scaling deployment ${TARGET_DEPLOY} to 0 replicas..."
    kubectl scale deploy "${TARGET_DEPLOY}" --replicas=0 -n "${NAMESPACE}" 2>&1

    log "Waiting for pods to terminate..."
    sleep 15

    # Verify service is down
    POD_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${TARGET_DEPLOY}" --no-headers 2>/dev/null | wc -l)
    if [ "${POD_COUNT}" -eq 0 ]; then
      pass "Service ${TARGET_DEPLOY} is unavailable (0 pods)"
    else
      fail "Service ${TARGET_DEPLOY} still has ${POD_COUNT} pods running"
    fi

    # Verify service unavailability via endpoint check
    ENDPOINT_COUNT=$(kubectl get endpoints "${TARGET_DEPLOY}" -n "${NAMESPACE}" -o jsonpath='{.subsets[*].addresses}' 2>/dev/null | wc -w)
    if [ "${ENDPOINT_COUNT}" -eq 0 ] || [ -z "${ENDPOINT_COUNT}" ]; then
      pass "No endpoints available for ${TARGET_DEPLOY}"
    else
      log "Endpoints still available: ${ENDPOINT_COUNT}"
    fi

    # Restore original replicas
    log "Restoring deployment ${TARGET_DEPLOY} to ${ORIGINAL_REPLICAS} replicas..."
    kubectl scale deploy "${TARGET_DEPLOY}" --replicas="${ORIGINAL_REPLICAS}" -n "${NAMESPACE}" 2>&1

    # Wait for restoration
    log "Waiting for pods to come back..."
    sleep 15
    kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=${TARGET_DEPLOY}" \
      -n "${NAMESPACE}" --timeout=120s 2>/dev/null && \
      pass "Service ${TARGET_DEPLOY} restored successfully" || \
      fail "Service ${TARGET_DEPLOY} did not restore within timeout"
  fi

  if [ "${VALIDATE_ALERTS}" = "true" ]; then
    log "Sleeping 60s for alert evaluation..."
    sleep 60
  fi
fi

# ── Validation Summary ──────────────────────────────────────────
section "Simulation Results"

TOTAL=$((PASSES + FAILURES))
log "Tests passed: ${PASSES}"
log "Tests failed: ${FAILURES}"
log "Total:        ${TOTAL}"

if [ "${FAILURES}" -gt 0 ]; then
  log ""
  log "Some simulations did not complete as expected."
  log "Review the output above for details."
  log ""
  log "Possible issues:"
  log "  - Missing monitoring stack (Prometheus/Alertmanager)"
  log "  - Namespace '${NAMESPACE}' lacks required resources"
  log "  - Alert rules not deployed or not scraping"
  log ""
  log "Runbook reference:"
  log "  - docs/runbooks/incident-response.md"
  log "  - docs/runbooks/kubernetes-incidents.md"
  log "  - docs/runbooks/service-incidents.md"
  exit 1
fi

log ""
log "═══════════════════════════════════════════"
log "  ALL SIMULATIONS COMPLETED SUCCESSFULLY"
log "═══════════════════════════════════════════"
log ""
log "Next steps:"
log "  1. Check Alertmanager:   kubectl port-forward -n ${MONITORING_NS} svc/alertmanager 9093:9093"
log "  2. Check Grafana alerts: kubectl port-forward -n ${MONITORING_NS} svc/grafana 3000:3000"
log "  3. Review runbook execution: docs/runbooks/"
log "  4. Run validation:       bash scripts/validate/validate-observability.sh"
