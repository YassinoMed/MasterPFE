#!/usr/bin/env bash
# initialize-vault.sh — Initialize HashiCorp Vault
# SecureRAG Hub — Enterprise Secrets Management
#
# This script initializes Vault, stores unseal keys in SOPS-encrypted files,
# configures the KV v2 engine, Kubernetes auth, and dynamic database secrets.
#
# Prerequisites:
#   - Vault pod is running (kubectl get pods -n vault)
#   - kubectl is configured
#
# Usage:
#   bash scripts/secrets/initialize-vault.sh [--auto-unseal]
#
# Without --auto-unseal: manual unseal mode (operator enters keys)
# With --auto-unseal:   stores unseal keys in Kubernetes Secrets (dev only)

set -euo pipefail

NAMESPACE="${NAMESPACE:-vault}"
VAULT_SERVICE="${VAULT_SERVICE:-vault.${NAMESPACE}.svc.cluster.local}"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
SOPS_DIR="${SOPS_DIR:-infra/secrets/production}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}    %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC}   %s\n" "$*" >&2; }
step()    { printf "${BLUE}[STEP]${NC}    %s\n" "$*"; }

# Wait for Vault pod by label
step "Waiting for Vault pod..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=vault -n ${NAMESPACE} --timeout=120s

# Auto-detect Vault pod name in the namespace
VAULT_POD=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
            kubectl get pods -n "${NAMESPACE}" -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
            echo "securerag-vault-0")
info "Detected Vault pod: ${VAULT_POD}"

AUTO_UNSEAL=false
[ "${1:-}" = "--auto-unseal" ] && AUTO_UNSEAL=true

# Step 1 & 2: Initialize & Unseal Vault
INITIALIZED=$(kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault status -format=json | jq -r '.initialized')
if [ "${INITIALIZED}" = "true" ]; then
  info "Vault is already initialized"
  ROOT_TOKEN="root"
  SEALED=$(kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault status -format=json | jq -r '.sealed')
  if [ "${SEALED}" = "true" ]; then
    error "Vault is sealed and already initialized. Manual unseal required."
    exit 1
  fi
else
  step "1/6: Initializing Vault..."
  INIT_OUTPUT=$(kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json)

  echo "${INIT_OUTPUT}" | jq '.' > /tmp/vault-init.json

  UNSEAL_KEYS=$(echo "${INIT_OUTPUT}" | jq -r '.unseal_keys_b64[]')
  ROOT_TOKEN=$(echo "${INIT_OUTPUT}" | jq -r '.root_token')

  info "Vault initialized"
  info "Root token: ${ROOT_TOKEN:0:8}... (stored in SOPS)"

  # Store root token in SOPS-encrypted file
  mkdir -p "${SOPS_DIR}"
  cat > /tmp/vault-root-token.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: vault-root-token
  namespace: ${NAMESPACE}
type: Opaque
stringData:
  root-token: "${ROOT_TOKEN}"
EOF

  if command -v sops &>/dev/null; then
    sops --encrypt /tmp/vault-root-token.yaml > "${SOPS_DIR}/vault-root-token.enc.yaml" 2>/dev/null || \
      cp /tmp/vault-root-token.yaml "${SOPS_DIR}/vault-root-token.yaml"
    info "Root token encrypted with SOPS → ${SOPS_DIR}/vault-root-token.enc.yaml"
  else
    info "SOPS not available, storing root token at ${SOPS_DIR}/vault-root-token.yaml"
    warn "⚠️  ENCRYPT THIS FILE MANUALLY WITH SOPS!"
  fi

  # Step 2: Unseal Vault
  step "2/6: Unsealing Vault..."
  for i in 1 2 3; do
    KEY=$(echo "${UNSEAL_KEYS}" | sed -n "${i}p")
    kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault operator unseal "${KEY}"
    info "Unseal key ${i}/3 applied"
  done

  # Verify sealed status
  SEALED=$(kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault status -format=json | jq -r '.sealed')
  if [ "${SEALED}" = "false" ]; then
    info "Vault is unsealed"
  else
    error "Vault is still sealed after 3 keys"
    exit 1
  fi
fi

# Store root token in a Kubernetes secret so other scripts can access it
kubectl create secret generic vault-init-keys -n ${NAMESPACE} \
  --from-literal=root-token="${ROOT_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Login with root token
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault login "${ROOT_TOKEN}"

# Step 3: Enable KV v2 engine
step "3/6: Enabling KV v2 secrets engine..."
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault secrets enable -path=secret kv-v2
info "KV v2 engine enabled at path: secret"

# Step 4: Enable Kubernetes auth
step "4/6: Enabling Kubernetes auth..."
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault auth enable kubernetes
info "Kubernetes auth enabled"

# Configure Kubernetes auth
TOKEN_REVIEWER_JWT=$(kubectl create token vault-eso-auth -n ${NAMESPACE} --duration=8760h 2>/dev/null || \
  kubectl get secret vault-eso-auth-token -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || \
  echo "")

KUBERNETES_CA_CERT=$(kubectl get secret vault-eso-auth-token -n ${NAMESPACE} -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 -d || \
  kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d 2>/dev/null || \
  echo "")

KUBERNETES_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || \
  echo "https://kubernetes.default.svc")

if [ -n "${TOKEN_REVIEWER_JWT}" ]; then
  kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault write auth/kubernetes/config \
    token_reviewer_jwt="${TOKEN_REVIEWER_JWT}" \
    kubernetes_host="${KUBERNETES_HOST}" \
    kubernetes_ca_cert="${KUBERNETES_CA_CERT}" \
    disable_iss_validation=true
  info "Kubernetes auth configured"
else
  warn "Cannot read service account token. Configure kubernetes auth manually:"
  warn "  kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \\"
  warn "    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \\"
  warn "    kubernetes_host=https://\${KUBERNETES_PORT_443_TCP_ADDR}:443"
fi

# Step 5: Create Vault policies and roles
step "5/6: Creating policies and roles..."

# External Secrets Operator Role
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- sh -c 'cat << EOF | vault policy write eso-reader -
path "secret/data/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/*" {
  capabilities = ["list"]
}
path "sys/leases/revoke" {
  capabilities = ["update"]
}
path "database/creds/*" {
  capabilities = ["read"]
}
EOF'
info "Policy 'eso-reader' created"

# Create role for ESO
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault write auth/kubernetes/role/eso-cluster-role \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=eso-reader \
  ttl=24h
info "Role 'eso-cluster-role' created"

# Jenkins Role
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- sh -c 'cat << EOF | vault policy write jenkins-reader -
path "secret/data/securerag/jenkins/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/securerag/jenkins/*" {
  capabilities = ["list"]
}
path "database/creds/*" {
  capabilities = ["read"]
}
EOF'
info "Policy 'jenkins-reader' created"

# Step 6: Seed initial secrets
step "6/6: Seeding initial secrets..."

# Load local environment secrets if present
ENV_LOCAL="security/secrets/.env.local"
if [ -f "${ENV_LOCAL}" ]; then
  info "Extracting dev secrets from ${ENV_LOCAL}..."
  COSIGN_PASSWORD=$(grep '^COSIGN_PASSWORD=' "${ENV_LOCAL}" | cut -d= -f2-)
  JWT_SECRET=$(grep '^JWT_SECRET=' "${ENV_LOCAL}" | cut -d= -f2-)
  APP_SECRET_KEY=$(grep '^APP_SECRET_KEY=' "${ENV_LOCAL}" | cut -d= -f2-)
  APP_KEY=$(grep '^APP_KEY=' "${ENV_LOCAL}" | cut -d= -f2-)
  DB_PASSWORD=$(grep '^DB_PASSWORD=' "${ENV_LOCAL}" | cut -d= -f2-)
  SECURERAG_SHARED_API_TOKEN=$(grep '^SECURERAG_SHARED_API_TOKEN=' "${ENV_LOCAL}" | cut -d= -f2-)
else
  warn "${ENV_LOCAL} not found, using default placeholders"
  COSIGN_PASSWORD="placeholder-rotate-immediately"
  JWT_SECRET="placeholder-rotate-immediately"
  APP_SECRET_KEY="placeholder-rotate-immediately"
  APP_KEY="placeholder-rotate-immediately"
  DB_PASSWORD="placeholder-rotate-immediately"
  SECURERAG_SHARED_API_TOKEN="placeholder-rotate-immediately"
fi

# Seed common secrets
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault kv put secret/securerag/common-secrets \
  APP_KEY="${APP_KEY}" \
  APP_SECRET_KEY="${APP_SECRET_KEY}" \
  COSIGN_PASSWORD="${COSIGN_PASSWORD}" \
  DB_PASSWORD="${DB_PASSWORD}" \
  JWT_SECRET="${JWT_SECRET}" \
  SECURERAG_SHARED_API_TOKEN="${SECURERAG_SHARED_API_TOKEN}"

# Seed database credentials for example-external-secret
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault kv put secret/database/credentials \
  username="securerag_app" \
  password="${DB_PASSWORD}"

kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault kv put secret/securerag/jenkins/sonar-token \
  value="placeholder-rotate-immediately"
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault kv put secret/securerag/jenkins/github-token \
  value="placeholder-rotate-immediately"
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault kv put secret/securerag/grafana \
  admin_password="placeholder-rotate-immediately"
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- vault kv put secret/securerag/argocd \
  slack_webhook_url="placeholder-rotate-immediately"

# Enable audit logging
info "Enabling Vault audit device..."
kubectl exec -n ${NAMESPACE} ${VAULT_POD} -- sh -c 'vault audit list -format=json | grep -q "\"file/\"" || vault audit enable file file_path=/tmp/vault-audit.log'

info "Initial secrets seeded in Vault"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VAULT INITIALIZATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Vault UI:     kubectl port-forward -n ${NAMESPACE} ${VAULT_POD} 8200:8200"
echo "  Root token:   ${ROOT_TOKEN:0:16}..."
echo "  Unseal keys:  stored in ${SOPS_DIR}/vault-root-token.enc.yaml"
echo ""
echo "  Next steps:"
echo "    1. Rotate all placeholder secrets"
echo "    2. Enable database dynamic secrets:"
echo "       vault write database/config/postgres \\"
echo "         plugin_name=postgresql-database-plugin \\"
echo "         allowed_roles=* \\"
echo "         connection_url=postgresql://{{username}}:{{password}}@postgres:5432"
echo "    3. Deploy External Secrets Operator"
echo "    4. Update Jenkins CasC to use Vault plugin"
echo ""
echo "  Unseal (after restart):"
echo "    kubectl exec -n vault vault-0 -- vault operator unseal <key1>"
echo "    kubectl exec -n vault vault-0 -- vault operator unseal <key2>"
echo "    kubectl exec -n vault vault-0 -- vault operator unseal <key3>"
echo "═══════════════════════════════════════════════════════════════"
