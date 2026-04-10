#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
SECRET_NAME="${SECRET_NAME:-securerag-common-secrets}"
SECRETS_FILE="${SECRETS_FILE:-security/secrets/.env.local}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

command -v kubectl >/dev/null 2>&1 || { error "kubectl is required"; exit 2; }

if [[ ! -f "${SECRETS_FILE}" ]]; then
  error "Secrets file not found: ${SECRETS_FILE}"
  error "Create it from security/secrets/.env.example in a non-versioned local file."
  exit 1
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-env-file="${SECRETS_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

info "Secret ${SECRET_NAME} applied to namespace ${NAMESPACE}"
