#!/usr/bin/env bash
# security/vault/vault-init.sh
# Automates HashiCorp Vault initialization, unsealing, and configuration for SecureRAG Hub.
# Targets the active Vault pod in the 'vault' namespace.

set -euo pipefail

VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
SECRET_NAMESPACE="${SECRET_NAMESPACE:-securerag-hub}"

echo "[INFO] Waiting for Vault pod to be running..."
kubectl wait --namespace "${VAULT_NAMESPACE}" \
  --for=condition=Ready pod/"${VAULT_POD}" \
  --timeout=120s

# Check if Vault is already initialized
IS_INITIALIZED=$(kubectl exec -n "${VAULT_NAMESPACE}" -c vault "${VAULT_POD}" -- vault status -format=json | grep -o '"initialized":[^,]*' | cut -d: -f2)

if [ "${IS_INITIALIZED}" = "false" ]; then
  echo "[INFO] Initializing Vault..."
  # Initialize Vault with a single key share/threshold for development/recette environment
  INIT_OUTPUT=$(kubectl exec -n "${VAULT_NAMESPACE}" -c vault "${VAULT_POD}" -- vault operator init -key-shares=1 -key-threshold=1 -format=json)
  
  # Extract keys (using simple python parse to avoid dependency issues in minimal runtimes)
  UNSEAL_KEY=$(echo "${INIT_OUTPUT}" | python3 -c "import sys, json; print(json.load(sys.stdin)['unseal_keys_b64'][0])")
  ROOT_TOKEN=$(echo "${INIT_OUTPUT}" | python3 -c "import sys, json; print(json.load(sys.stdin)['root_token'])")

  echo "[INFO] Vault Initialized successfully."
  echo "[WARNING] Save the following keys securely. NEVER check them into Git!"
  echo "Unseal Key: <PLACEHOLDER_UNSEAL_KEY> (Actual: ${UNSEAL_KEY})"
  echo "Root Token: <PLACEHOLDER_ROOT_TOKEN> (Actual: ${ROOT_TOKEN})"

  # Store keys in a Kubernetes Secret for local automation convenience
  kubectl create secret generic vault-init-keys \
    --namespace "${VAULT_NAMESPACE}" \
    --from-literal=unseal-key="${UNSEAL_KEY}" \
    --from-literal=root-token="${ROOT_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "[INFO] Vault is already initialized. Retrieving credentials from Kubernetes Secret..."
  UNSEAL_KEY=$(kubectl get secret vault-init-keys -n "${VAULT_NAMESPACE}" -o jsonpath='{.data.unseal-key}' | base64 -d)
  ROOT_TOKEN=$(kubectl get secret vault-init-keys -n "${VAULT_NAMESPACE}" -o jsonpath='{.data.root-token}' | base64 -d)
fi

# Unseal Vault if it is sealed
IS_SEALED=$(kubectl exec -n "${VAULT_NAMESPACE}" -c vault "${VAULT_POD}" -- vault status -format=json | grep -o '"sealed":[^,]*' | cut -d: -f2)
if [ "${IS_SEALED}" = "true" ]; then
  echo "[INFO] Unsealing Vault..."
  kubectl exec -n "${VAULT_NAMESPACE}" -c vault "${VAULT_POD}" -- vault operator unseal "${UNSEAL_KEY}"
fi

# Helper function to execute Vault CLI commands as Root
vault_cmd() {
  kubectl exec -n "${VAULT_NAMESPACE}" -c vault "${VAULT_POD}" -- env VAULT_TOKEN="${ROOT_TOKEN}" vault "$@"
}

echo "[INFO] Configuring Vault Engines..."
# Enable KV v2 secrets engine
vault_cmd secrets list -format=json | grep -q '"secret/":' || \
  vault_cmd secrets enable -path=secret kv-v2

# Enable Transit encryption engine (replacing SOPS)
vault_cmd secrets list -format=json | grep -q '"transit/":' || \
  vault_cmd secrets enable transit

# Create the transit key for Cosign and pipeline encryption
vault_cmd write -f transit/keys/jenkins-cosign-key

echo "[INFO] Uploading policies..."
# Write Policies
vault_cmd policy write jenkins-ci - < security/vault/policies/jenkins-ci-policy.hcl
vault_cmd policy write portal-web-policy - < security/vault/policies/portal-web-policy.hcl
vault_cmd policy write chatbot-manager-policy - < security/vault/policies/chatbot-manager-policy.hcl
vault_cmd policy write auth-users-policy - < security/vault/policies/auth-users-policy.hcl
vault_cmd policy write conversation-service-policy - < security/vault/policies/conversation-service-policy.hcl
vault_cmd policy write audit-security-policy - < security/vault/policies/audit-security-policy.hcl

echo "[INFO] Configuring Auth Methods..."

# 1. Configure AppRole for Jenkins
vault_cmd auth list -format=json | grep -q '"approle/":' || \
  vault_cmd auth enable approle

vault_cmd write auth/approle/role/jenkins-ci \
  secret_id_ttl="1h" \
  token_num_uses=10 \
  token_ttl="1h" \
  token_max_ttl="1h" \
  policies="jenkins-ci"

# Read AppRole RoleID and SecretID (to be supplied to Jenkins credentials)
ROLE_ID=$(vault_cmd read -field=role_id auth/approle/role/jenkins-ci/role-id)
SECRET_ID=$(vault_cmd write -f -field=secret_id auth/approle/role/jenkins-ci/secret-id)

echo "[INFO] Jenkins AppRole configuration completed:"
echo "Role ID:   ${ROLE_ID}"
echo "Secret ID: <PLACEHOLDER_JENKINS_SECRET_ID> (Actual: ${SECRET_ID})"

# Store AppRole info in K8s Secret for Jenkins deployment reference
kubectl create secret generic vault-jenkins-approle \
  --namespace "${VAULT_NAMESPACE}" \
  --from-literal=role-id="${ROLE_ID}" \
  --from-literal=secret-id="${SECRET_ID}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Configure Kubernetes Auth Method for Pods
vault_cmd auth list -format=json | grep -q '"kubernetes/":' || \
  vault_cmd auth enable kubernetes

# Configure Vault to speak to local Kubernetes API server
vault_cmd write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443"

# Configure Roles bound to ServiceAccounts (Least Privilege)
vault_cmd write auth/kubernetes/role/securerag-portal-web \
  bound_service_account_names="sa-portal-web" \
  bound_service_account_namespaces="${SECRET_NAMESPACE}" \
  policies="portal-web-policy" \
  ttl="1h"

vault_cmd write auth/kubernetes/role/securerag-chatbot-manager \
  bound_service_account_names="sa-chatbot-manager" \
  bound_service_account_namespaces="${SECRET_NAMESPACE}" \
  policies="chatbot-manager-policy" \
  ttl="1h"

vault_cmd write auth/kubernetes/role/securerag-auth-users \
  bound_service_account_names="sa-auth-users" \
  bound_service_account_namespaces="${SECRET_NAMESPACE}" \
  policies="auth-users-policy" \
  ttl="1h"

vault_cmd write auth/kubernetes/role/securerag-conversation-service \
  bound_service_account_names="sa-conversation-service" \
  bound_service_account_namespaces="${SECRET_NAMESPACE}" \
  policies="conversation-service-policy" \
  ttl="1h"

vault_cmd write auth/kubernetes/role/securerag-audit-security-service \
  bound_service_account_names="sa-audit-security-service" \
  bound_service_account_namespaces="${SECRET_NAMESPACE}" \
  policies="audit-security-policy" \
  ttl="1h"

echo "[INFO] Vault Initialization and Configuration completed successfully."
