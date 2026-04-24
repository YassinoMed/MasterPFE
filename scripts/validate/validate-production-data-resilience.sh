#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-data-resilience.md}"
STRICT_PRODUCTION_DATA="${STRICT_PRODUCTION_DATA:-false}"

mkdir -p "${REPORT_DIR}"

status_from_file() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi

  local status
  status="$(grep -E '^- Status: `|^Statut global: `' "${file}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: `([^`]+)`.*/\1/' || true)"

  case "${status}" in
    TERMINÉ|PARTIEL|PRÊT_NON_EXÉCUTÉ|DÉPENDANT_DE_L_ENVIRONNEMENT|FAIL)
      printf '%s' "${status}"
      return 0
      ;;
    COMPLETE_PROVEN)
      printf 'TERMINÉ'
      return 0
      ;;
  esac

  if grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' "${file}"; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  elif grep -Fq 'PARTIEL' "${file}" || grep -Fq 'FAIL' "${file}" || grep -Fq 'WARN' "${file}"; then
    printf 'PARTIEL'
  elif grep -Fq 'TERMINÉ' "${file}"; then
    printf 'TERMINÉ'
  else
    printf 'PRÊT_NON_EXÉCUTÉ'
  fi
}

step_status_from_summary() {
  local file="$1"
  local step="$2"
  if [[ ! -s "${file}" ]]; then
    printf ''
    return 0
  fi

  python3 - "${file}" "${step}" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
step = sys.argv[2]
pattern = re.compile(r'^\|\s*(?P<step>[^|]+?)\s*\|\s*(?P<status>[^|]+?)\s*\|')
for line in path.read_text(encoding="utf-8").splitlines():
    match = pattern.match(line)
    if match and match.group("step").strip() == step:
        print(match.group("status").strip())
        break
PY
}

apps=(
  "platform/portal-web"
  "services-laravel/auth-users-service"
  "services-laravel/chatbot-manager-service"
  "services-laravel/conversation-service"
  "services-laravel/audit-security-service"
)

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

status="PRÊT_NON_EXÉCUTÉ"
failures=()
runtime_ready=true
static_ready=true
runtime_statuses=()

{
  printf '# Production Data Resilience - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Strict mode: `%s`\n\n' "${STRICT_PRODUCTION_DATA}"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${REPORT_FILE}"

for app in "${apps[@]}"; do
  dockerfile="${app}/Dockerfile"
  if grep -Fq 'pdo_mysql' "${dockerfile}" && grep -Fq 'pdo_pgsql' "${dockerfile}"; then
    printf '| `%s` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |\n' "${app}" >> "${REPORT_FILE}"
  else
    printf '| `%s` external DB PHP drivers | FAIL | Dockerfile does not install both `pdo_mysql` and `pdo_pgsql` |\n' "${app}" >> "${REPORT_FILE}"
    failures+=("${app}: missing pdo_mysql or pdo_pgsql")
  fi
done

if kubectl kustomize infra/k8s/overlays/production >/tmp/securerag-production-data.yaml 2>/dev/null; then
  if grep -Fq 'value: sqlite' /tmp/securerag-production-data.yaml; then
    printf '| Production kind overlay DB mode | PRÊT_NON_EXÉCUTÉ | `infra/k8s/overlays/production` keeps SQLite for local/kind compatibility |\n' >> "${REPORT_FILE}"
  else
    printf '| Production kind overlay DB mode | TERMINÉ | Render does not contain `DB_CONNECTION=sqlite` |\n' >> "${REPORT_FILE}"
  fi
else
  printf '| Production overlay render | FAIL | `kubectl kustomize infra/k8s/overlays/production` failed |\n' >> "${REPORT_FILE}"
  failures+=("production overlay render failed")
  static_ready=false
fi

if kubectl kustomize infra/k8s/overlays/production-external-db >/tmp/securerag-production-external-db.yaml 2>/dev/null; then
  if grep -Fq 'value: sqlite' /tmp/securerag-production-external-db.yaml; then
    printf '| External DB overlay SQLite removal | FAIL | `production-external-db` still renders SQLite |\n' >> "${REPORT_FILE}"
    failures+=("production-external-db still renders sqlite")
    static_ready=false
  else
    printf '| External DB overlay SQLite removal | TERMINÉ | `production-external-db` renders without SQLite |\n' >> "${REPORT_FILE}"
  fi

  if grep -Fq 'name: securerag-database-secrets' /tmp/securerag-production-external-db.yaml; then
    printf '| External DB secret references | TERMINÉ | workloads reference `securerag-database-secrets` |\n' >> "${REPORT_FILE}"
  else
    printf '| External DB secret references | FAIL | `securerag-database-secrets` not found in rendered overlay |\n' >> "${REPORT_FILE}"
    failures+=("external DB secret references missing")
    static_ready=false
  fi
else
  printf '| External DB overlay render | FAIL | `kubectl kustomize infra/k8s/overlays/production-external-db` failed |\n' >> "${REPORT_FILE}"
  failures+=("production-external-db overlay render failed")
  static_ready=false
fi

if [[ -f docs/runbooks/data-resilience.md ]]; then
  printf '| Data resilience runbook | TERMINÉ | `docs/runbooks/data-resilience.md` present |\n' >> "${REPORT_FILE}"
else
  printf '| Data resilience runbook | FAIL | `docs/runbooks/data-resilience.md` missing |\n' >> "${REPORT_FILE}"
  failures+=("data resilience runbook missing")
fi

if [[ -x scripts/data/backup-postgres.sh && -x scripts/data/restore-postgres.sh ]]; then
  printf '| Backup and restore scripts | TERMINÉ | `scripts/data/backup-postgres.sh` and `scripts/data/restore-postgres.sh` are executable |\n' >> "${REPORT_FILE}"
else
  printf '| Backup and restore scripts | FAIL | PostgreSQL backup/restore scripts missing or not executable |\n' >> "${REPORT_FILE}"
  failures+=("backup/restore scripts missing or not executable")
  static_ready=false
fi

data_resilience_summary_status="$(status_from_file artifacts/backup/data-resilience-proof.md)"
backup_step_status="$(step_status_from_summary artifacts/backup/data-resilience-proof.md "Backup")"
restore_step_status="$(step_status_from_summary artifacts/backup/data-resilience-proof.md "Restore")"

if [[ -z "${backup_step_status}" ]]; then
  if [[ -s artifacts/backup/backup-report.md ]] && grep -Fq 'Status: `TERMINÉ`' artifacts/backup/backup-report.md; then
    backup_step_status="TERMINÉ"
  else
    backup_step_status="${data_resilience_summary_status}"
  fi
fi

if [[ -z "${restore_step_status}" ]]; then
  if [[ -s artifacts/backup/restore-report.md ]] && grep -Fq 'Status: `TERMINÉ`' artifacts/backup/restore-report.md; then
    restore_step_status="TERMINÉ"
  else
    restore_step_status="${data_resilience_summary_status}"
  fi
fi

case "${backup_step_status}" in
  TERMINÉ)
    printf '| Backup runtime proof | TERMINÉ | `artifacts/backup/data-resilience-proof.md` |\n' >> "${REPORT_FILE}"
    ;;
  DÉPENDANT_DE_L_ENVIRONNEMENT)
    printf '| Backup runtime proof | DÉPENDANT_DE_L_ENVIRONNEMENT | missing PostgreSQL client tools or external DB runtime prerequisites |\n' >> "${REPORT_FILE}"
    runtime_ready=false
    runtime_statuses+=("DÉPENDANT_DE_L_ENVIRONNEMENT")
    ;;
  PARTIEL|FAIL)
    printf '| Backup runtime proof | PARTIEL | `artifacts/backup/data-resilience-proof.md` |\n' >> "${REPORT_FILE}"
    runtime_ready=false
    runtime_statuses+=("PARTIEL")
    ;;
  *)
    printf '| Backup runtime proof | PRÊT_NON_EXÉCUTÉ | run `scripts/data/backup-postgres.sh` against an external PostgreSQL DB |\n' >> "${REPORT_FILE}"
    runtime_ready=false
    runtime_statuses+=("PRÊT_NON_EXÉCUTÉ")
    ;;
esac

case "${restore_step_status}" in
  TERMINÉ)
    printf '| Restore runtime proof | TERMINÉ | `artifacts/backup/data-resilience-proof.md` |\n' >> "${REPORT_FILE}"
    ;;
  DÉPENDANT_DE_L_ENVIRONNEMENT)
    printf '| Restore runtime proof | DÉPENDANT_DE_L_ENVIRONNEMENT | missing PostgreSQL client tools or isolated restore DB runtime prerequisites |\n' >> "${REPORT_FILE}"
    runtime_ready=false
    runtime_statuses+=("DÉPENDANT_DE_L_ENVIRONNEMENT")
    ;;
  PARTIEL|FAIL)
    printf '| Restore runtime proof | PARTIEL | `artifacts/backup/data-resilience-proof.md` |\n' >> "${REPORT_FILE}"
    runtime_ready=false
    runtime_statuses+=("PARTIEL")
    ;;
  *)
    printf '| Restore runtime proof | PRÊT_NON_EXÉCUTÉ | run `scripts/data/restore-postgres.sh` into an isolated restore database |\n' >> "${REPORT_FILE}"
    runtime_ready=false
    runtime_statuses+=("PRÊT_NON_EXÉCUTÉ")
    ;;
esac

if [[ "${#failures[@]}" -eq 0 && "${static_ready}" == "true" && "${runtime_ready}" == "true" ]]; then
  status="TERMINÉ"
elif [[ "${#failures[@]}" -eq 0 && " ${runtime_statuses[*]} " == *" PARTIEL "* ]]; then
  status="PARTIEL"
elif [[ "${#failures[@]}" -eq 0 && " ${runtime_statuses[*]} " == *" DÉPENDANT_DE_L_ENVIRONNEMENT "* ]]; then
  status="DÉPENDANT_DE_L_ENVIRONNEMENT"
elif [[ "${#failures[@]}" -eq 0 && "${static_ready}" == "true" ]]; then
  status="PRÊT_NON_EXÉCUTÉ"
else
  status="FAIL"
fi

{
  printf '\n## Global status\n\n'
  printf 'Statut global: `%s`\n\n' "${status}"
  printf '## Interpretation\n\n'
  if [[ "${status}" == "TERMINÉ" ]]; then
    printf 'Production data resilience is proven with external DB overlay, backup and isolated restore evidence.\n'
  elif [[ "${status}" == "DÉPENDANT_DE_L_ENVIRONNEMENT" ]]; then
    printf 'Static production data resilience is ready, but the live proof is blocked by missing PostgreSQL client tooling or external DB runtime prerequisites.\n'
  elif [[ "${status}" == "PARTIEL" ]]; then
    printf 'The live backup/restore campaign started but did not complete cleanly. Review the summary proof before claiming production data resilience.\n'
  elif [[ "${status}" == "PRÊT_NON_EXÉCUTÉ" ]]; then
    printf 'Static production data resilience is ready. Runtime backup and restore still require an external PostgreSQL endpoint and credentials.\n'
  else
    printf 'Data resilience has blocking static gaps. Fix FAIL rows before presenting it as production-ready.\n'
  fi
  printf '\n## Required production evidence\n\n'
  printf -- '- External database endpoint and credentials injected through non-Git secrets.\n'
  printf -- '- Successful application migrations against the external database.\n'
  printf -- '- Backup artifact with checksum.\n'
  printf -- '- Restore test evidence on an isolated database or namespace.\n'
} >> "${REPORT_FILE}"

if [[ "${status}" != "TERMINÉ" ]] && is_true "${STRICT_PRODUCTION_DATA}"; then
  printf '[ERROR] Production data resilience is incomplete. Report: %s\n' "${REPORT_FILE}" >&2
  exit 1
fi

printf '[INFO] Production data resilience report written to %s\n' "${REPORT_FILE}"
