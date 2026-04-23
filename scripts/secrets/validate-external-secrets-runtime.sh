#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
EXTERNAL_SECRET_NAME="${EXTERNAL_SECRET_NAME:-securerag-database-secrets}"
TARGET_SECRET_NAME="${TARGET_SECRET_NAME:-securerag-database-secrets}"
SECRET_STORE_NAME="${SECRET_STORE_NAME:-vault-backend}"
SECRET_STORE_KIND="${SECRET_STORE_KIND:-ClusterSecretStore}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/external-secrets-runtime.md}"

mkdir -p "${REPORT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

row() {
  local control="$1"
  local status="$2"
  local evidence="$3"
  printf '| %s | %s | %s |\n' "${control}" "${status}" "${evidence}" >> "${REPORT_FILE}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 2; }
}

require_command kubectl

{
  printf '# External Secrets Runtime Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NAMESPACE}"
  printf -- '- ExternalSecret: `%s`\n' "${EXTERNAL_SECRET_NAME}"
  printf -- '- Target Secret: `%s`\n' "${TARGET_SECRET_NAME}"
  printf -- '- SecretStore kind/name: `%s/%s`\n' "${SECRET_STORE_KIND}" "${SECRET_STORE_NAME}"
  printf -- '- Status: `PENDING`\n\n'
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${REPORT_FILE}"

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  row "Kubernetes API" "DÉPENDANT_DE_L_ENVIRONNEMENT" "API server unreachable"
  python3 - "${REPORT_FILE}" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text(encoding="utf-8").replace("- Status: `PENDING`", "- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`", 1), encoding="utf-8")
PY
  info "External Secrets runtime report written to ${REPORT_FILE}"
  exit 0
fi

row "Kubernetes API" "TERMINÉ" "API server reachable"

if ! kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; then
  row "External Secrets CRD" "DÉPENDANT_DE_L_ENVIRONNEMENT" "CRD externalsecrets.external-secrets.io missing"
  final_status="DÉPENDANT_DE_L_ENVIRONNEMENT"
else
  row "External Secrets CRD" "TERMINÉ" "CRD externalsecrets.external-secrets.io present"
  final_status="PRÊT_NON_EXÉCUTÉ"

  store_resource="$(tr '[:upper:]' '[:lower:]' <<< "${SECRET_STORE_KIND}")"
  if kubectl get "${store_resource}" "${SECRET_STORE_NAME}" >/dev/null 2>&1; then
    row "SecretStore reference" "TERMINÉ" "${SECRET_STORE_KIND}/${SECRET_STORE_NAME} present"
  else
    row "SecretStore reference" "PRÊT_NON_EXÉCUTÉ" "${SECRET_STORE_KIND}/${SECRET_STORE_NAME} missing"
  fi

  if kubectl get externalsecret -n "${NAMESPACE}" "${EXTERNAL_SECRET_NAME}" >/dev/null 2>&1; then
    ready_condition="$(
      kubectl get externalsecret -n "${NAMESPACE}" "${EXTERNAL_SECRET_NAME}" \
        -o jsonpath='{range .status.conditions[*]}{.type}={.status}{";"}{end}' 2>/dev/null || true
    )"
    if kubectl get secret -n "${NAMESPACE}" "${TARGET_SECRET_NAME}" >/dev/null 2>&1 && grep -Fq 'Ready=True' <<< "${ready_condition}"; then
      row "ExternalSecret reconciliation" "TERMINÉ" "Ready=True and target Secret ${TARGET_SECRET_NAME} exists"
      final_status="TERMINÉ"
    elif kubectl get secret -n "${NAMESPACE}" "${TARGET_SECRET_NAME}" >/dev/null 2>&1; then
      row "ExternalSecret reconciliation" "PARTIEL" "target Secret exists but conditions=${ready_condition:-none}"
      final_status="PARTIEL"
    else
      row "ExternalSecret reconciliation" "PARTIEL" "ExternalSecret present but target Secret ${TARGET_SECRET_NAME} missing"
      final_status="PARTIEL"
    fi
  else
    row "ExternalSecret reconciliation" "PRÊT_NON_EXÉCUTÉ" "ExternalSecret ${EXTERNAL_SECRET_NAME} not applied in namespace ${NAMESPACE}"
  fi
fi

{
  printf '\n## Runtime objects\n\n```text\n'
  kubectl get externalsecret -A 2>&1 || true
  printf '\n'
  kubectl get secret -n "${NAMESPACE}" "${TARGET_SECRET_NAME}" 2>&1 || true
  printf '\n```\n'
} >> "${REPORT_FILE}"

python3 - "${REPORT_FILE}" "${final_status}" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
status = sys.argv[2]
path.write_text(path.read_text(encoding="utf-8").replace("- Status: `PENDING`", f"- Status: `{status}`", 1), encoding="utf-8")
PY

info "External Secrets runtime report written to ${REPORT_FILE}"
