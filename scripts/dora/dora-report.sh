#!/usr/bin/env bash
# Fichier : scripts/dora/dora-report.sh
# Génère un rapport DORA Metrics au format Markdown avec les valeurs
# courantes et les tendances.

set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
OUTPUT_FILE="${OUTPUT_FILE:-dora-report.md}"
SERVICES="${SERVICES:-api-gateway auth-service rag-service admin-panel}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

command -v curl >/dev/null 2>&1 || { error "curl is required"; exit 2; }
command -v jq >/dev/null 2>&1 || { error "jq is required"; exit 2; }

prom_query() {
  local query="$1"
  curl -fsS -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${query}" 2>/dev/null | jq -r '.data.result[] // empty'
}

classify_dora() {
  local metric="$1" value="$2"
  case "${metric}" in
    deployment_frequency)
      if (( $(echo "${value} >= 1" | bc -l 2>/dev/null || echo 0) )); then echo "Elite"
      elif (( $(echo "${value} >= 0.14" | bc -l 2>/dev/null || echo 0) )); then echo "High"
      elif (( $(echo "${value} >= 0.033" | bc -l 2>/dev/null || echo 0) )); then echo "Medium"
      else echo "Low"
      fi
      ;;
    lead_time)
      if (( $(echo "${value} < 86400" | bc -l 2>/dev/null || echo 0) )); then echo "Elite"
      elif (( $(echo "${value} < 604800" | bc -l 2>/dev/null || echo 0) )); then echo "High"
      elif (( $(echo "${value} < 2592000" | bc -l 2>/dev/null || echo 0) )); then echo "Medium"
      else echo "Low"
      fi
      ;;
    mttr)
      if (( $(echo "${value} < 3600" | bc -l 2>/dev/null || echo 0) )); then echo "Elite"
      elif (( $(echo "${value} < 86400" | bc -l 2>/dev/null || echo 0) )); then echo "High"
      elif (( $(echo "${value} < 604800" | bc -l 2>/dev/null || echo 0) )); then echo "Medium"
      else echo "Low"
      fi
      ;;
    change_failure_rate)
      if (( $(echo "${value} < 0.05" | bc -l 2>/dev/null || echo 0) )); then echo "Elite"
      elif (( $(echo "${value} < 0.10" | bc -l 2>/dev/null || echo 0) )); then echo "High"
      elif (( $(echo "${value} < 0.15" | bc -l 2>/dev/null || echo 0) )); then echo "Medium"
      else echo "Low"
      fi
      ;;
  esac
}

# --- Query Prometheus for current DORA metrics ---

{
  printf '# DORA Metrics Report\n'
  printf '**Generated:** %s\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '**Data Source:** Prometheus (%s)\n\n' "${PROMETHEUS_URL}"
  printf '## Summary\n\n'

  # Overall metrics
  df_global="$(prom_query 'securerag:dora:deployment_frequency:rate7d' | jq -r '.value[1] // "N/A"' | head -1)"
  lt_global="$(prom_query 'securerag:dora:lead_time:seconds' | jq -r '.value[1] // "N/A"' | head -1)"
  mttr_global="$(prom_query 'securerag:dora:mttr:seconds' | jq -r '.value[1] // "N/A"' | head -1)"
  cfr_global="$(prom_query 'securerag:dora:change_failure_rate:ratio' | jq -r '.value[1] // "N/A"' | head -1)"

  printf '| Metric | Current Value | DORA Classification |\n'
  printf '|--------|--------------|---------------------|\n'
  printf '| Deployment Frequency | %s deploys/day | %s |\n' \
    "${df_global}" "$(classify_dora deployment_frequency "${df_global:-0}")"
  printf '| Lead Time for Changes | %s s | %s |\n' \
    "${lt_global}" "$(classify_dora lead_time "${lt_global:-999999}")"
  printf '| Mean Time to Recovery | %s s | %s |\n' \
    "${mttr_global}" "$(classify_dora mttr "${mttr_global:-999999}")"
  printf '| Change Failure Rate | %s%% | %s |\n' \
    "$(echo "${cfr_global:-0} * 100" | bc -l 2>/dev/null || echo 0)" \
    "$(classify_dora change_failure_rate "${cfr_global:-1}")"

  printf '\n## Per-Service Breakdown\n\n'

  for svc in ${SERVICES}; do
    printf '### %s\n\n' "${svc}"
    df="$(prom_query "securerag:dora:deployment_frequency:rate7d{service=\"${svc}\"}" | jq -r '.value[1] // "N/A"')"
    lt="$(prom_query "securerag:dora:lead_time:seconds{service=\"${svc}\"}" | jq -r '.value[1] // "N/A"')"
    mttr="$(prom_query "securerag:dora:mttr:seconds{service=\"${svc}\"}" | jq -r '.value[1] // "N/A"')"
    cfr="$(prom_query "securerag:dora:change_failure_rate:ratio{service=\"${svc}\"}" | jq -r '.value[1] // "N/A"')"

    printf '| Metric | Value | Class |\n'
    printf '|--------|-------|-------|\n'
    printf '| Deploy Frequency | %s | %s |\n' "${df}" "$(classify_dora deployment_frequency "${df:-0}")"
    printf '| Lead Time | %s s | %s |\n' "${lt}" "$(classify_dora lead_time "${lt:-999999}")"
    printf '| MTTR | %s s | %s |\n' "${mttr}" "$(classify_dora mttr "${mttr:-999999}")"
    printf '| Change Failure Rate | %s%% | %s |\n' \
      "$(echo "${cfr:-0} * 100" | bc -l 2>/dev/null || echo 0)" \
      "$(classify_dora change_failure_rate "${cfr:-1}")"
    printf '\n'
  done

  printf '## DORA Targets\n\n'
  printf '| Classification | Deploy Frequency | Lead Time | MTTR | Change Failure Rate |\n'
  printf '|---------------|-----------------|-----------|------|--------------------|\n'
  printf '| **Elite** | > daily | < 1 day | < 1 hour | < 5%% |\n'
  printf '| **High** | > weekly | < 1 week | < 1 day | < 10%% |\n'
  printf '| **Medium** | > monthly | < 1 month | < 1 week | < 15%% |\n'
  printf '| **Low** | <= monthly | > 1 month | > 1 week | >= 15%% |\n'

  printf '\n## Trends (30d)\n\n'
  printf '> Run the following Prometheus queries to view detailed trends:\n\n'
  printf '```\n'
  printf 'Deployment Frequency:\navg_over_time(securerag:dora:deployment_frequency:rate7d[30d])\n\n'
  printf 'Lead Time:\navg_over_time(securerag:dora:lead_time:seconds[30d])\n\n'
  printf 'MTTR:\navg_over_time(securerag:dora:mttr:seconds[30d])\n\n'
  printf 'Change Failure Rate:\navg_over_time(securerag:dora:change_failure_rate:ratio[30d])\n'
  printf '```\n'

} > "${OUTPUT_FILE}"

info "DORA report written to ${OUTPUT_FILE}"
