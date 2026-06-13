#!/usr/bin/env bash

set -euo pipefail

JENKINS_SECRETS_DIR="${JENKINS_SECRETS_DIR:-infra/jenkins/secrets}"
COSIGN_PASSWORD_FILE="${COSIGN_PASSWORD_FILE:-${JENKINS_SECRETS_DIR}/cosign.password}"
COSIGN_PRIVATE_KEY="${COSIGN_PRIVATE_KEY:-${JENKINS_SECRETS_DIR}/cosign.key}"
COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-${JENKINS_SECRETS_DIR}/cosign.pub}"
JENKINS_ADMIN_PASSWORD_FILE="${JENKINS_ADMIN_PASSWORD_FILE:-${JENKINS_SECRETS_DIR}/jenkins-admin-password}"
SONAR_TOKEN_FILE="${SONAR_TOKEN_FILE:-${JENKINS_SECRETS_DIR}/sonar-token}"
GMAIL_USER_FILE="${GMAIL_USER_FILE:-${JENKINS_SECRETS_DIR}/gmail-user}"
GMAIL_APP_PASSWORD_FILE="${GMAIL_APP_PASSWORD_FILE:-${JENKINS_SECRETS_DIR}/gmail-app-password}"
COSIGN_PASSWORD_VALUE="${COSIGN_PASSWORD_VALUE:-}"
SONAR_TOKEN_VALUE="${SONAR_TOKEN_VALUE:-}"
GMAIL_USER_VALUE="${GMAIL_USER_VALUE:-}"
GMAIL_APP_PASSWORD_VALUE="${GMAIL_APP_PASSWORD_VALUE:-}"
COSIGN_IMAGE="${COSIGN_IMAGE:-gcr.io/projectsigstore/cosign:v2.5.3}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

mkdir -p "${JENKINS_SECRETS_DIR}"
umask 077

if [[ ! -f "${JENKINS_ADMIN_PASSWORD_FILE}" ]]; then
  python3 - <<'PY' > "${JENKINS_ADMIN_PASSWORD_FILE}"
import secrets
print(secrets.token_urlsafe(48))
PY
  info "Generated local Jenkins admin password file at ${JENKINS_ADMIN_PASSWORD_FILE}"
fi

chmod 600 "${JENKINS_ADMIN_PASSWORD_FILE}"

if [[ -n "${SONAR_TOKEN_VALUE}" ]]; then
  printf '%s\n' "${SONAR_TOKEN_VALUE}" > "${SONAR_TOKEN_FILE}"
  info "Wrote local Sonar token material to ${SONAR_TOKEN_FILE}"
fi

if [[ -n "${GMAIL_USER_VALUE}" ]]; then
  printf '%s' "${GMAIL_USER_VALUE}" > "${GMAIL_USER_FILE}"
  info "Wrote Gmail user material to ${GMAIL_USER_FILE}"
fi

if [[ -n "${GMAIL_APP_PASSWORD_VALUE}" ]]; then
  printf '%s' "${GMAIL_APP_PASSWORD_VALUE}" > "${GMAIL_APP_PASSWORD_FILE}"
  info "Wrote Gmail App Password material to ${GMAIL_APP_PASSWORD_FILE}"
fi

if [[ -f "${SONAR_TOKEN_FILE}" ]]; then
  chmod 600 "${SONAR_TOKEN_FILE}"
fi

if [[ -f "${GMAIL_USER_FILE}" ]]; then
  chmod 600 "${GMAIL_USER_FILE}"
fi

if [[ -f "${GMAIL_APP_PASSWORD_FILE}" ]]; then
  chmod 600 "${GMAIL_APP_PASSWORD_FILE}"
fi

if [[ -z "${COSIGN_PASSWORD_VALUE}" ]]; then
  if [[ -f "${COSIGN_PASSWORD_FILE}" ]]; then
    COSIGN_PASSWORD_VALUE="$(tr -d '\r\n' < "${COSIGN_PASSWORD_FILE}")"
  else
    COSIGN_PASSWORD_VALUE="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"
    printf '%s\n' "${COSIGN_PASSWORD_VALUE}" > "${COSIGN_PASSWORD_FILE}"
  fi
fi

if [[ -f "${COSIGN_PRIVATE_KEY}" && -f "${COSIGN_PUBLIC_KEY}" ]]; then
  info "Cosign key pair already present in ${JENKINS_SECRETS_DIR}"
  exit 0
fi

if command -v cosign >/dev/null 2>&1; then
  info "Generating local Cosign key pair with the host binary"
  COSIGN_PASSWORD="${COSIGN_PASSWORD_VALUE}" cosign generate-key-pair --output-key-prefix "${JENKINS_SECRETS_DIR}/cosign"
else
  command -v docker >/dev/null 2>&1 || { error "docker is required when cosign is not installed locally"; exit 2; }
  info "Generating local Cosign key pair with ${COSIGN_IMAGE}"
  # Temporarily relax permissions so the non-root Cosign container can write
  chmod 777 "${JENKINS_SECRETS_DIR}"
  docker run --rm \
    -e COSIGN_PASSWORD="${COSIGN_PASSWORD_VALUE}" \
    -v "$(cd "${JENKINS_SECRETS_DIR}" && pwd):/keys" \
    "${COSIGN_IMAGE}" \
    generate-key-pair --output-key-prefix /keys/cosign
  chmod 700 "${JENKINS_SECRETS_DIR}"
fi

chmod 600 "${COSIGN_PRIVATE_KEY}" "${COSIGN_PASSWORD_FILE}"
chmod 644 "${COSIGN_PUBLIC_KEY}"

info "Local Jenkins credentials material prepared in ${JENKINS_SECRETS_DIR}"
