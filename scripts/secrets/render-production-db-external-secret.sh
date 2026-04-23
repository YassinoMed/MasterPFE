#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
EXTERNAL_SECRET_NAME="${EXTERNAL_SECRET_NAME:-securerag-database-secrets}"
TARGET_SECRET_NAME="${TARGET_SECRET_NAME:-securerag-database-secrets}"
SECRET_STORE_NAME="${SECRET_STORE_NAME:-vault-backend}"
SECRET_STORE_KIND="${SECRET_STORE_KIND:-ClusterSecretStore}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-1h}"
REMOTE_REF_KEY="${REMOTE_REF_KEY:-kv/data/securerag-hub/production/db}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
RENDERED_FILE="${RENDERED_FILE:-${REPORT_DIR}/securerag-database.external-secret.yaml}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/external-secrets-render.md}"
APPLY="${APPLY:-false}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

if is_true "${APPLY}"; then
  command -v kubectl >/dev/null 2>&1 || { error "Missing required command: kubectl"; exit 2; }
fi

mkdir -p "${REPORT_DIR}"

cat > "${RENDERED_FILE}" <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${EXTERNAL_SECRET_NAME}
  namespace: ${NAMESPACE}
spec:
  refreshInterval: ${REFRESH_INTERVAL}
  secretStoreRef:
    kind: ${SECRET_STORE_KIND}
    name: ${SECRET_STORE_NAME}
  target:
    name: ${TARGET_SECRET_NAME}
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      type: Opaque
  data:
    - secretKey: DB_CONNECTION
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: DB_CONNECTION
    - secretKey: DB_HOST
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: DB_HOST
    - secretKey: DB_PORT
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: DB_PORT
    - secretKey: DB_USERNAME
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: DB_USERNAME
    - secretKey: DB_PASSWORD
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: DB_PASSWORD
    - secretKey: DB_SSLMODE
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: DB_SSLMODE
    - secretKey: PORTAL_WEB_DB_DATABASE
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: PORTAL_WEB_DB_DATABASE
    - secretKey: AUTH_USERS_DB_DATABASE
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: AUTH_USERS_DB_DATABASE
    - secretKey: CHATBOT_MANAGER_DB_DATABASE
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: CHATBOT_MANAGER_DB_DATABASE
    - secretKey: CONVERSATION_SERVICE_DB_DATABASE
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: CONVERSATION_SERVICE_DB_DATABASE
    - secretKey: AUDIT_SECURITY_SERVICE_DB_DATABASE
      remoteRef:
        key: ${REMOTE_REF_KEY}
        property: AUDIT_SECURITY_SERVICE_DB_DATABASE
EOF

status="TERMINÉ"
action="manifest rendered without secret values"
if is_true "${APPLY}"; then
  kubectl apply -f "${RENDERED_FILE}" >/dev/null
  action="manifest rendered and applied; runtime reconciliation still depends on External Secrets Operator"
fi

{
  printf '# External Secrets Render Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NAMESPACE}"
  printf -- '- ExternalSecret: `%s`\n' "${EXTERNAL_SECRET_NAME}"
  printf -- '- SecretStore kind/name: `%s/%s`\n' "${SECRET_STORE_KIND}" "${SECRET_STORE_NAME}"
  printf -- '- Remote ref key: `%s`\n' "${REMOTE_REF_KEY}"
  printf -- '- Rendered manifest: `%s`\n' "${RENDERED_FILE}"
  printf -- '- Status: `%s`\n\n' "${status}"
  printf '## Action\n\n%s.\n' "${action}"
} > "${REPORT_FILE}"

info "External Secrets render report written to ${REPORT_FILE}"
