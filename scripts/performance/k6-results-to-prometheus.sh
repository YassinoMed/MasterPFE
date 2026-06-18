#!/usr/bin/env bash
# k6-results-to-prometheus.sh
# Converts k6 JSON results to Prometheus textfile collector format.
# Designed to be run periodically by the node_exporter textfile collector
# or called at the end of a k6 test suite.
#
# Usage:
#   k6-results-to-prometheus.sh <k6-summary.json> [output-file]
#
# If output-file is omitted, writes to stdout.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <k6-summary.json> [output-file]" >&2
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"

if [ ! -f "${INPUT_FILE}" ]; then
  echo "Error: input file not found: ${INPUT_FILE}" >&2
  exit 1
fi

# ── Metadata ──────────────────────────────────────────────────────────
TIMESTAMP=$(date +%s)
INSTANCE="${HOSTNAME:-unknown}"
JOB="k6-performance"

# ── Helpers ───────────────────────────────────────────────────────────
prom_metric() {
  local name="$1"
  local type="$2"
  local help="$3"
  echo "# HELP ${name} ${help}"
  echo "# TYPE ${name} ${type}"
}

is_number() {
  [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

# ── Generate Prometheus metrics ───────────────────────────────────────
{
  prom_metric "k6_http_reqs_total" "counter" "Total number of HTTP requests"
  prom_metric "k6_http_req_duration_seconds" "gauge" "HTTP request duration in seconds (summary)"

  # Parse summary JSON with jq
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
  fi

  ROOT=$(cat "${INPUT_FILE}")

  # ── Root HTTP metrics ────────────────────────────────────────────
  HTTP_REQS_COUNT=$(echo "${ROOT}" | jq -r '.metrics.http_reqs // {} | .values.count // 0')
  HTTP_REQS_RATE=$(echo "${ROOT}" | jq -r '.metrics.http_reqs // {} | .values.rate // 0')
  HTTP_REQ_FAILED_RATE=$(echo "${ROOT}" | jq -r '.metrics.http_req_failed // {} | .values.rate // 0')
  HTTP_REQ_DUR_AVG=$(echo "${ROOT}" | jq -r '.metrics.http_req_duration // {} | .values.avg // 0')
  HTTP_REQ_DUR_P95=$(echo "${ROOT}" | jq -r '.metrics.http_req_duration // {} | .values."p(95)" // 0')
  HTTP_REQ_DUR_P99=$(echo "${ROOT}" | jq -r '.metrics.http_req_duration // {} | .values."p(99)" // 0')
  HTTP_REQ_DUR_MAX=$(echo "${ROOT}" | jq -r '.metrics.http_req_duration // {} | .values.max // 0')

  is_number "${HTTP_REQS_COUNT}" || HTTP_REQS_COUNT=0
  is_number "${HTTP_REQS_RATE}" || HTTP_REQS_RATE=0
  is_number "${HTTP_REQ_FAILED_RATE}" || HTTP_REQ_FAILED_RATE=0
  is_number "${HTTP_REQ_DUR_AVG}" || HTTP_REQ_DUR_AVG=0
  is_number "${HTTP_REQ_DUR_P95}" || HTTP_REQ_DUR_P95=0
  is_number "${HTTP_REQ_DUR_P99}" || HTTP_REQ_DUR_P99=0
  is_number "${HTTP_REQ_DUR_MAX}" || HTTP_REQ_DUR_MAX=0

  cat <<EOF
k6_http_reqs_total{instance="${INSTANCE}",job="${JOB}"} ${HTTP_REQS_COUNT} ${TIMESTAMP}
k6_http_reqs_rate{instance="${INSTANCE}",job="${JOB}"} ${HTTP_REQS_RATE} ${TIMESTAMP}
k6_http_req_failed_rate{instance="${INSTANCE}",job="${JOB}"} ${HTTP_REQ_FAILED_RATE} ${TIMESTAMP}
k6_http_req_duration_avg_seconds{instance="${INSTANCE}",job="${JOB}"} ${HTTP_REQ_DUR_AVG} ${TIMESTAMP}
k6_http_req_duration_p95_seconds{instance="${INSTANCE}",job="${JOB}"} ${HTTP_REQ_DUR_P95} ${TIMESTAMP}
k6_http_req_duration_p99_seconds{instance="${INSTANCE}",job="${JOB}"} ${HTTP_REQ_DUR_P99} ${TIMESTAMP}
k6_http_req_duration_max_seconds{instance="${INSTANCE}",job="${JOB}"} ${HTTP_REQ_DUR_MAX} ${TIMESTAMP}
EOF

  # ── Per-service metrics from custom metrics ──────────────────────
  for metric in $(echo "${ROOT}" | jq -r '.metrics | to_entries[] | select(.key | startswith("request_duration") or startswith("smoke_duration") or startswith("spike_duration") or startswith("endurance_duration")) | .key'); do
    AVG=$(echo "${ROOT}" | jq -r ".metrics[\"${metric}\"].values.avg // 0")
    P95=$(echo "${ROOT}" | jq -r ".metrics[\"${metric}\"].values.\"p(95)\" // 0")
    P99=$(echo "${ROOT}" | jq -r ".metrics[\"${metric}\"].values.\"p(99)\" // 0")
    MAX=$(echo "${ROOT}" | jq -r ".metrics[\"${metric}\"].values.max // 0")

    is_number "${AVG}" || AVG=0
    is_number "${P95}" || P95=0
    is_number "${P99}" || P99=0
    is_number "${MAX}" || MAX=0

    METRIC_SAFE=$(echo "${metric}" | sed 's/[^a-zA-Z0-9_]/_/g')
    cat <<EOF
k6_${METRIC_SAFE}_avg_seconds{instance="${INSTANCE}",job="${JOB}"} ${AVG} ${TIMESTAMP}
k6_${METRIC_SAFE}_p95_seconds{instance="${INSTANCE}",job="${JOB}"} ${P95} ${TIMESTAMP}
k6_${METRIC_SAFE}_p99_seconds{instance="${INSTANCE}",job="${JOB}"} ${P99} ${TIMESTAMP}
k6_${METRIC_SAFE}_max_seconds{instance="${INSTANCE}",job="${JOB}"} ${MAX} ${TIMESTAMP}
EOF
  done

  # ── Error rate metrics ──────────────────────────────────────────
  for metric in $(echo "${ROOT}" | jq -r '.metrics | to_entries[] | select(.key | endswith("_errors") or endswith("error_rate")) | .key'); do
    RATE=$(echo "${ROOT}" | jq -r ".metrics[\"${metric}\"].values.rate // 0")
    is_number "${RATE}" || RATE=0
    METRIC_SAFE=$(echo "${metric}" | sed 's/[^a-zA-Z0-9_]/_/g')
    echo "k6_${METRIC_SAFE}_rate{instance=\"${INSTANCE}\",job=\"${JOB}\"} ${RATE} ${TIMESTAMP}"
  done

  # ── SLO gate metric ─────────────────────────────────────────────
  # 1 = passed, 0 = failed
  if echo "${ROOT}" | jq -e '.metrics.thresholds // empty' > /dev/null 2>&1; then
    ALL_PASSED=$(echo "${ROOT}" | jq '[.metrics.thresholds[] | .ok] | all')
    if [ "${ALL_PASSED}" = "true" ]; then
      echo "k6_slo_gate{instance=\"${INSTANCE}\",job=\"${JOB}\"} 1 ${TIMESTAMP}"
    else
      echo "k6_slo_gate{instance=\"${INSTANCE}\",job=\"${JOB}\"} 0 ${TIMESTAMP}"
    fi
  else
    echo "k6_slo_gate{instance=\"${INSTANCE}\",job=\"${JOB}\"} 0 ${TIMESTAMP}"
  fi

} | (
  if [ -n "${OUTPUT_FILE}" ]; then
    cat > "${OUTPUT_FILE}"
    echo "Written ${OUTPUT_FILE}" >&2
  else
    cat
  fi
)
