#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
CRONJOB_NAME="${CRONJOB_NAME:-securerag-postgres-backup}"
REPORT_FILE="${REPORT_FILE:-artifacts/backup/scheduled-backup-report.md}"
RUN_BACKUP_CRONJOB_NOW="${RUN_BACKUP_CRONJOB_NOW:-false}"

is_true() { case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }
mkdir -p "$(dirname "${REPORT_FILE}")"

status="PRÊT_NON_EXÉCUTÉ"
detail="CronJob manifest exists but no live CronJob was found."

if ! command -v kubectl >/dev/null 2>&1; then
  status="DÉPENDANT_DE_L_ENVIRONNEMENT"
  detail="kubectl is required."
elif kubectl get cronjob "${CRONJOB_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  cron="$(kubectl get cronjob "${CRONJOB_NAME}" -n "${NAMESPACE}" -o wide 2>&1)"
  suspend="$(kubectl get cronjob "${CRONJOB_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.suspend}' 2>/dev/null || true)"
  status="TERMINÉ"
  detail="${cron}"
  if [[ "${suspend}" == "true" ]]; then
    status="PRÊT_NON_EXÉCUTÉ"
    detail="${cron}\nCronJob is installed but suspended."
  fi

  if is_true "${RUN_BACKUP_CRONJOB_NOW}"; then
    job_name="${CRONJOB_NAME}-manual-$(date -u '+%Y%m%d%H%M%S')"
    kubectl create job "${job_name}" -n "${NAMESPACE}" --from=cronjob/"${CRONJOB_NAME}" >/dev/null
    detail="${detail}\nManual job created: ${job_name}"
  fi
fi

{
  printf '# Scheduled PostgreSQL Backup Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "${status}"
  printf -- '- Namespace: `%s`\n' "${NAMESPACE}"
  printf -- '- CronJob: `%s`\n\n' "${CRONJOB_NAME}"
  printf '## Detail\n\n```text\n%s\n```\n' "${detail}"
} > "${REPORT_FILE}"

printf '[INFO] Scheduled backup report written to %s\n' "${REPORT_FILE}"
