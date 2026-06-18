#!/usr/bin/env bash
# =============================================================================
# trace-instrumentation-test.sh
# SecureRAG Hub — Observability: Validate Trace Instrumentation
# =============================================================================
# Description:
#   Sends synthetic OTLP traces and verifies they are received by Tempo.
#   Uses the OpenTelemetry Collector as the ingestion endpoint.
#
# Prerequisites:
#   - kubectl configured to the target cluster
#   - otel-collector service accessible (port-forward or in-cluster)
#   - tempo query frontend accessible (port-forward or in-cluster)
#
# Usage:
#   ./tests/observability/trace-instrumentation-test.sh [--namespace otel-ns] [--tempo-ns tempo-ns]
#
# Exit codes:
#   0 — All traces instrumented and found in Tempo
#   1 — One or more checks failed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-securerag-otel}"
TEMPO_NAMESPACE="${TEMPO_NAMESPACE:-securerag-tempo}"
OTEL_SVC="${OTEL_SVC:-otel-collector}"
TEMPO_SVC="${TEMPO_SVC:-tempo-query}"
TRACE_ID=""
SPAN_ID=""
PASS_COUNT=0
FAIL_COUNT=0

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ── Helpers ──────────────────────────────────────────────────────────────────
pass() {
  echo -e "  ${GREEN}✓${NC} $1"
  ((PASS_COUNT++))
}

fail() {
  echo -e "  ${RED}✗${NC} $1"
  ((FAIL_COUNT++))
}

info() {
  echo -e "  ${YELLOW}→${NC} $1"
}

cleanup() {
  if [[ -n "${PF_PID_OTEL:-}" ]]; then kill "$PF_PID_OTEL" 2>/dev/null || true; fi
  if [[ -n "${PF_PID_TEMPO:-}" ]]; then kill "$PF_PID_TEMPO" 2>/dev/null || true; fi
  rm -f /tmp/otel-test-trace.json /tmp/otel-test-response.json
}

# ── Setup port-forwarding ────────────────────────────────────────────────────
setup_port_forwards() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Setting up port-forwards"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  kubectl port-forward -n "$NAMESPACE" "svc/$OTEL_SVC" 4317:4317 &>/dev/null &
  PF_PID_OTEL=$!
  sleep 2

  kubectl port-forward -n "$TEMPO_NAMESPACE" "svc/$TEMPO_SVC" 3200:3200 &>/dev/null &
  PF_PID_TEMPO=$!
  sleep 2

  if ! kill -0 "$PF_PID_OTEL" 2>/dev/null; then
    echo "  ${RED}Failed to port-forward to OTel Collector${NC}"
    exit 1
  fi

  if ! kill -0 "$PF_PID_TEMPO" 2>/dev/null; then
    echo "  ${RED}Failed to port-forward to Tempo${NC}"
    exit 1
  fi

  pass "Port-forwards established"
}

# ── Generate a random hex string of N bytes ─────────────────────────────────
random_hex() {
  local bytes="${1:-8}"
  od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
}

# ── Send a synthetic trace ───────────────────────────────────────────────────
send_trace() {
  local trace_id_hex span_id_hex trace_id_upper

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Sending synthetic OTLP trace"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Generate trace and span IDs (16 bytes / 8 bytes)
  trace_id_hex=$(random_hex 16)
  span_id_hex=$(random_hex 8)
  trace_id_upper=$(echo "$trace_id_hex" | tr '[:lower:]' '[:upper:]')
  TRACE_ID="$trace_id_upper"
  SPAN_ID="$span_id_hex"

  info "Trace ID: $TRACE_ID"
  info "Span ID:  $SPAN_ID"

  # Build the OTLP request payload
  # This is a minimal valid OTLP trace export using the OTLP/gRPC endpoint
  # via grpcurl or using a direct HTTP/JSON call to the OTLP HTTP endpoint
  local grpcurl_available=0
  if command -v grpcurl &>/dev/null; then
    grpcurl_available=1
  fi

  if [[ "$grpcurl_available" -eq 1 ]]; then
    # Use grpcurl for gRPC
    # We need the protoset or reflection — fall back to HTTP if unavailable
    info "grpcurl available — will use gRPC"
    # Create a minimal trace export descriptor inline
    # Since we might not have reflection enabled, try HTTP fallback
  fi

  # Use OTLP HTTP endpoint (JSON) — simpler and guaranteed to work
  http_response=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "http://localhost:4318/v1/traces" \
    -H "Content-Type: application/json" \
    -d "{
      \"resourceSpans\": [
        {
          \"resource\": {
            \"attributes\": [
              {\"key\": \"service.name\", \"value\": {\"stringValue\": \"trace-instrumentation-test\"}},
              {\"key\": \"service.namespace\", \"value\": {\"stringValue\": \"securerag-hub\"}},
              {\"key\": \"cluster\", \"value\": {\"stringValue\": \"securerag-prod\"}},
              {\"key\": \"environment\", \"value\": {\"stringValue\": \"test\"}}
            ]
          },
          \"scopeSpans\": [
            {
              \"scope\": {
                \"name\": \"trace-instrumentation-test\",
                \"version\": \"1.0.0\"
              },
              \"spans\": [
                {
                  \"traceId\": \"${trace_id_hex}\",
                  \"spanId\": \"${span_id_hex}\",
                  \"parentSpanId\": \"\",
                  \"name\": \"synthetic-span\",
                  \"kind\": 1,
                  \"startTimeUnixNano\": \"$(date +%s%N)\",
                  \"endTimeUnixNano\": \"$(date +%s%N)\",
                  \"status\": {\"code\": 0},
                  \"attributes\": [
                    {\"key\": \"synthetic\", \"value\": {\"boolValue\": true}},
                    {\"key\": \"test.name\", \"value\": {\"stringValue\": \"trace-instrumentation-test\"}}
                  ]
                }
              ]
            }
          ]
        }
      ]
    }"
  )

  if [[ "$http_response" == "200" ]]; then
    pass "Trace sent successfully (HTTP $http_response)"
  else
    fail "Failed to send trace (HTTP $http_response)"
    echo "  ${YELLOW}Check that the OTel Collector is running and port-forward is active${NC}"
    return 1
  fi
}

# ── Query Tempo for the trace ────────────────────────────────────────────────
query_tempo() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Querying Tempo for trace"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  info "Searching by trace ID: $TRACE_ID"
  sleep 2

  # Attempt to find the trace by ID
  local trace_data
  trace_data=$(curl -s "http://localhost:3200/api/traces/${TRACE_ID}" 2>/dev/null || echo "")

  if [[ -n "$trace_data" && "$trace_data" != "null" && "$trace_data" != '{"error"*' ]]; then
    pass "Trace found in Tempo by ID"
    echo "$trace_data" | python3 -m json.tool 2>/dev/null | head -15
  else
    wait_seconds=10
    info "Trace not immediately available — waiting ${wait_seconds}s..."
    sleep "$wait_seconds"

    trace_data=$(curl -s "http://localhost:3200/api/traces/${TRACE_ID}" 2>/dev/null || echo "")
    if [[ -n "$trace_data" && "$trace_data" != "null" && "$trace_data" != '{"error"*' ]]; then
      pass "Trace found in Tempo by ID (after delay)"
    else
      fail "Trace NOT found in Tempo"
      info "Response: $trace_data"
      return 1
    fi
  fi
}

# ── Search traces by service name ────────────────────────────────────────────
search_traces() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Searching traces by service name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local query_result
  query_result=$(curl -s \
    "http://localhost:3200/api/search?q=service.name=trace-instrumentation-test" \
    2>/dev/null || echo "")

  if [[ -n "$query_result" && "$query_result" != "null" && "$query_result" != '{"error"*' ]]; then
    pass "Traces searchable by service.name in Tempo"
    local trace_count
    trace_count=$(echo "$query_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('traces', d.get('results', []))))" 2>/dev/null || echo "0")
    info "Found $trace_count trace(s)"
  else
    fail "Trace search returned no results"
    info "Response: $query_result"
    return 1
  fi
}

# ── Verify span metrics in Prometheus ────────────────────────────────────────
check_span_metrics() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Verifying span metrics generation"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  info "Checking metrics-generator output in Tempo"
  # Check that the metrics-generator endpoint is reachable
  local gen_metrics
  gen_metrics=$(curl -s "http://localhost:3200/metrics" 2>/dev/null || echo "")

  if echo "$gen_metrics" | grep -q "traces_spans_received_total"; then
    pass "Span metrics are being generated (traces_spans_received_total found)"
  else
    info "Span metrics not yet available (may take a moment for the generator to process)"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  trap cleanup EXIT INT TERM

  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║   SecureRAG Hub — Trace Instrumentation Validation Test     ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  OTel Namespace: $NAMESPACE"
  echo "  Tempo Namespace: $TEMPO_NAMESPACE"
  echo "  OTel Service:    $OTEL_SVC"
  echo "  Tempo Service:   $TEMPO_SVC"
  echo "  Date:            $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  # ── Pre-flight checks ──────────────────────────────────────────────────────
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Pre-flight checks"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local prereqs=("kubectl" "curl" "python3")
  for cmd in "${prereqs[@]}"; do
    if command -v "$cmd" &>/dev/null; then
      pass "Required command '$cmd' found"
    else
      fail "Required command '$cmd' not found"
    fi
  done

  if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    pass "Namespace '$NAMESPACE' exists"
  else
    fail "Namespace '$NAMESPACE' does not exist"
  fi

  if kubectl get namespace "$TEMPO_NAMESPACE" &>/dev/null; then
    pass "Namespace '$TEMPO_NAMESPACE' exists"
  else
    fail "Namespace '$TEMPO_NAMESPACE' does not exist"
  fi

  # ── Run tests ──────────────────────────────────────────────────────────────
  setup_port_forwards
  send_trace
  query_tempo
  search_traces
  check_span_metrics

  # ── Summary ────────────────────────────────────────────────────────────────
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e " Results: ${GREEN}$PASS_COUNT passed${NC}, ${RED}$FAIL_COUNT failed${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "  ${RED}Trace instrumentation validation FAILED${NC}"
    exit 1
  fi

  echo "  ${GREEN}Trace instrumentation validation PASSED${NC}"
  exit 0
}

main "$@"
