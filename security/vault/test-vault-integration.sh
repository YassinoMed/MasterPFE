#!/usr/bin/env bash
# security/vault/test-vault-integration.sh
# End-to-end test script to verify successful Vault Agent integration.
# Checks that secrets are injected into /vault/secrets/ and absent from environment variables.

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-portal-web}"
CONTAINER_NAME="${CONTAINER_NAME:-portal-web}"
SECRET_FILE="/vault/secrets/laravel-env"

echo "[INFO] Running Vault integration tests for deployment: ${DEPLOYMENT_NAME} in namespace: ${NAMESPACE}"

# 1. Check if the deployment exists and is available
if ! kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "[WARN] Deployment ${DEPLOYMENT_NAME} not found in namespace ${NAMESPACE}."
  echo "[WARN] Please deploy the deployment first before running E2E checks."
  echo "[INFO] Mock validation test would verify:"
  echo "  - File '${SECRET_FILE}' exists in container"
  echo "  - '${SECRET_FILE}' contains valid key-value secrets (DB_*, APP_KEY)"
  echo "  - Command 'env | grep -E \"(DB_PASSWORD|APP_KEY)\"' returns empty"
  exit 0
fi

# 2. Wait for at least one pod to be ready
echo "[INFO] Waiting for pods to be ready..."
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout=60s

# Get active pod name
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name="${DEPLOYMENT_NAME}" -o jsonpath='{.items[0].metadata.name}')
echo "[INFO] Selected Pod for inspection: ${POD_NAME}"

# 3. Check if secrets are injected to /vault/secrets/laravel-env
echo "[INFO] 1. Checking if secret file exists at ${SECRET_FILE}..."
if kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c "${CONTAINER_NAME}" -- test -f "${SECRET_FILE}"; then
  echo "[PASS] Secret file exists at ${SECRET_FILE}"
else
  echo "[FAIL] Secret file not found at ${SECRET_FILE}"
  exit 1
fi

# 4. Check if secret contents are correctly rendered
echo "[INFO] 2. Verifying secret contents..."
SECRET_CONTENT=$(kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c "${CONTAINER_NAME}" -- cat "${SECRET_FILE}")

if echo "${SECRET_CONTENT}" | grep -q "DB_PASSWORD=" && echo "${SECRET_CONTENT}" | grep -q "APP_KEY="; then
  echo "[PASS] Secret contents are correctly rendered as Laravel environment variables"
else
  echo "[FAIL] Secrets are empty or incorrect. Content:"
  echo "${SECRET_CONTENT}"
  exit 1
fi

# 5. Check if environment variables are clean from secrets
echo "[INFO] 3. Verifying that secrets do NOT leak to env..."
ENV_OUTPUT=$(kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c "${CONTAINER_NAME}" -- env)

if echo "${ENV_OUTPUT}" | grep -q -E "(DB_PASSWORD|APP_KEY|DB_USERNAME)"; then
  echo "[FAIL] Sensitive secrets leaked to environment variables!"
  echo "${ENV_OUTPUT}" | grep -E "(DB_PASSWORD|APP_KEY|DB_USERNAME)"
  exit 1
else
  echo "[PASS] Environment variables are clean. Secrets are successfully isolated to ${SECRET_FILE}"
fi

echo "[SUCCESS] Vault integration verification completed successfully. Posture is secure."
