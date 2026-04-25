#!/usr/bin/env bash

set -euo pipefail

MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
PROM_REPORT="${PROM_REPORT:-artifacts/observability/prometheus-targets.md}"
GRAFANA_REPORT="${GRAFANA_REPORT:-artifacts/observability/grafana-dashboard-proof.md}"
LOKI_REPORT="${LOKI_REPORT:-artifacts/observability/loki-logs-proof.md}"
ALERT_REPORT="${ALERT_REPORT:-artifacts/observability/alertmanager-rules.md}"
SLO_REPORT="${SLO_REPORT:-artifacts/observability/slo-summary.md}"

mkdir -p "$(dirname "${PROM_REPORT}")"

write_report() {
  local file="$1"
  local title="$2"
  local status="$3"
  local detail="$4"
  {
    printf '# %s - SecureRAG Hub\n\n' "${title}"
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Namespace: `%s`\n\n' "${MONITORING_NAMESPACE}"
    printf '## Detail\n\n```text\n%s\n```\n' "${detail}"
  } > "${file}"
}

if ! command -v kubectl >/dev/null 2>&1; then
  for item in \
    "${PROM_REPORT}|Prometheus Targets|DÉPENDANT_DE_L_ENVIRONNEMENT|kubectl missing" \
    "${GRAFANA_REPORT}|Grafana Dashboard Proof|DÉPENDANT_DE_L_ENVIRONNEMENT|kubectl missing" \
    "${LOKI_REPORT}|Loki Logs Proof|DÉPENDANT_DE_L_ENVIRONNEMENT|kubectl missing" \
    "${ALERT_REPORT}|Alertmanager Rules|DÉPENDANT_DE_L_ENVIRONNEMENT|kubectl missing" \
    "${SLO_REPORT}|SLO Summary|DÉPENDANT_DE_L_ENVIRONNEMENT|kubectl missing"; do
    IFS='|' read -r file title status detail <<<"${item}"
    write_report "${file}" "${title}" "${status}" "${detail}"
  done
  exit 0
fi

if ! kubectl get namespace "${MONITORING_NAMESPACE}" >/dev/null 2>&1; then
  write_report "${PROM_REPORT}" "Prometheus Targets" "PRÊT_NON_EXÉCUTÉ" "Monitoring namespace is not installed."
  write_report "${GRAFANA_REPORT}" "Grafana Dashboard Proof" "PRÊT_NON_EXÉCUTÉ" "Monitoring namespace is not installed."
  write_report "${LOKI_REPORT}" "Loki Logs Proof" "PRÊT_NON_EXÉCUTÉ" "Monitoring namespace is not installed."
  write_report "${ALERT_REPORT}" "Alertmanager Rules" "PRÊT_NON_EXÉCUTÉ" "Monitoring namespace is not installed."
  write_report "${SLO_REPORT}" "SLO Summary" "PRÊT_NON_EXÉCUTÉ" "Monitoring namespace is not installed."
  exit 0
fi

prom_detail="$(kubectl get pods,svc,servicemonitor,prometheusrule -n "${MONITORING_NAMESPACE}" 2>&1 || true)"
grafana_detail="$(kubectl get deploy,svc,cm -n "${MONITORING_NAMESPACE}" -l app.kubernetes.io/name=grafana 2>&1 || kubectl get svc -n "${MONITORING_NAMESPACE}" | grep -i grafana || true)"
loki_detail="$(kubectl get pods,svc -n "${MONITORING_NAMESPACE}" | grep -Ei 'loki|promtail' || true)"
alert_detail="$(kubectl get prometheusrule -n "${MONITORING_NAMESPACE}" 2>&1 || true)"
slo_detail="$(
  {
    printf 'SLO targets:\n'
    printf -- '- portal health availability > 99%%\n'
    printf -- '- official pods Ready > 99%%\n'
    printf -- '- P95 portal health latency < 500 ms\n\n'
    kubectl get servicemonitor,prometheusrule,cm -n "${MONITORING_NAMESPACE}" 2>&1 || true
  }
)"

[[ "${prom_detail}" == *"prometheus"* ]] && prom_status="TERMINÉ" || prom_status="PARTIEL"
[[ "${grafana_detail}" == *"grafana"* ]] && grafana_status="TERMINÉ" || grafana_status="PRÊT_NON_EXÉCUTÉ"
[[ "${loki_detail}" == *"loki"* ]] && loki_status="TERMINÉ" || loki_status="PRÊT_NON_EXÉCUTÉ"
[[ "${alert_detail}" == *"securerag"* || "${alert_detail}" == *"PrometheusRule"* ]] && alert_status="TERMINÉ" || alert_status="PRÊT_NON_EXÉCUTÉ"
[[ "${slo_detail}" == *"securerag-slo-rules"* && "${slo_detail}" == *"securerag-portal-health"* ]] && slo_status="TERMINÉ" || slo_status="PRÊT_NON_EXÉCUTÉ"

write_report "${PROM_REPORT}" "Prometheus Targets" "${prom_status}" "${prom_detail}"
write_report "${GRAFANA_REPORT}" "Grafana Dashboard Proof" "${grafana_status}" "${grafana_detail}"
write_report "${LOKI_REPORT}" "Loki Logs Proof" "${loki_status}" "${loki_detail}"
write_report "${ALERT_REPORT}" "Alertmanager Rules" "${alert_status}" "${alert_detail}"
write_report "${SLO_REPORT}" "SLO Summary" "${slo_status}" "${slo_detail}"

printf '[INFO] Observability reports written to artifacts/observability\n'
