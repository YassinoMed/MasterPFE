#!/usr/bin/env bash
# enable-dynamic-secrets.sh — Enable Vault Dynamic Secrets for PostgreSQL
# SecureRAG Hub — Enterprise Dynamic Credentials Management
#
# This script configures the Vault database secrets engine with:
#   - PostgreSQL connection using rotating root credentials
#   - Dynamic role "securerag-app" with 1h TTL
#   - Vault policy "dynamic-secrets" for lease management
#   - Kubernetes auth role for dynamic secrets access
#
# Usage:
#   bash scripts/vault/enable-dynamic-secrets.sh [--dry-run]
#
# Prerequisites:
#   - Vault is initialized and unsealed
#   - vault-0 pod is running in the vault namespace
#   - kubectl is configured with cluster access
#   - PostgreSQL root credentials are stored in Vault KV or provided via env

set -euo pipefail

NAMESPACE="${NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-securerag-hub}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"
POLICY_FILE="${POLICY_FILE:-/tmp/dynamic-secrets-policy.hcl}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}    %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC}   %s\n" "$*" >&2; }
step()    { printf "${BLUE}[STEP]${NC}    %s\n" "$*"; }

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

POSTGRES_CONNECTION_URL="postgresql://{{username}}:{{password}}@${POSTGRES_SERVICE}.${POSTGRES_NAMESPACE}.svc.cluster.local:5432/securerag?sslmode=disable"

# Retrieve PostgreSQL root credentials from Vault KV
step "Retrieving PostgreSQL root credentials from Vault..."
PG_ROOT_USER="${PG_ROOT_USER:-}"
PG_ROOT_PASS="${PG_ROOT_PASS:-}"

if [ -z "${PG_ROOT_USER}" ] || [ -z "${PG_ROOT_PASS}" ]; then
  PG_SECRET=$(kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault kv get -format=json secret/securerag/database 2>/dev/null || true)
  if [ -n "${PG_SECRET}" ]; then
    PG_ROOT_USER=$(echo "${PG_SECRET}" | jq -r '.data.data.DB_USERNAME // empty')
    PG_ROOT_PASS=$(echo "${PG_SECRET}" | jq -r '.data.data.DB_PASSWORD // empty')
  fi
fi

if [ -z "${PG_ROOT_USER}" ] || [ -z "${PG_ROOT_PASS}" ]; then
  warn "Could not retrieve PostgreSQL root credentials from Vault KV"
  warn "Using default credentials — update after configuration"
  PG_ROOT_USER="${PG_ROOT_USER:-vault_root}"
  PG_ROOT_PASS="${PG_ROOT_PASS:-changeme}"
fi

# Step 1: Enable database secrets engine
step "1/6: Enabling database secrets engine..."
if $DRY_RUN; then
  info "[DRY-RUN] vault secrets enable -path=database/ database"
else
  kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault secrets enable -path=database/ database
  info "Database secrets engine enabled at path: database/"
fi

# Step 2: Configure PostgreSQL connection
step "2/6: Configuring PostgreSQL connection..."
if $DRY_RUN; then
  info "[DRY-RUN] vault write database/config/postgres-securerag ..."
  info "  connection_url: ${POSTGRES_CONNECTION_URL}"
  info "  username: ${PG_ROOT_USER}"
  info "  password: [REDACTED]"
else
  kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault write database/config/postgres-securerag \
    plugin_name=postgresql-database-plugin \
    allowed_roles="securerag-app" \
    connection_url="${POSTGRES_CONNECTION_URL}" \
    username="${PG_ROOT_USER}" \
    password="${PG_ROOT_PASS}" \
    verify_connection=false
  info "PostgreSQL connection 'postgres-securerag' configured"
fi

# Step 3: Create dynamic role
step "3/6: Creating dynamic role 'securerag-app'..."
CREATION_STATEMENTS="CREATE USER \"{{name}}\" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"

if $DRY_RUN; then
  info "[DRY-RUN] vault write database/roles/securerag-app ..."
  info "  creation_statements: ${CREATION_STATEMENTS}"
  info "  default_ttl: 1h"
  info "  max_ttl: 24h"
else
  kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault write database/roles/securerag-app \
    db_name=postgres-securerag \
    creation_statements="${CREATION_STATEMENTS}" \
    default_ttl=1h \
    max_ttl=24h
  info "Role 'securerag-app' created with 1h default TTL, 24h max TTL"
fi

# Step 4: Create Vault policy
step "4/6: Creating Vault policy 'dynamic-secrets'..."
if $DRY_RUN; then
  info "[DRY-RUN] vault policy write dynamic-secrets <policy.hcl>"
else
  cat << 'POLICY_EOF' | kubectl exec -i -n "${NAMESPACE}" "${VAULT_POD}" -- vault policy write dynamic-secrets -
path "database/creds/securerag-app" {
  capabilities = ["read"]
}
path "database/roles/*" {
  capabilities = ["read", "list"]
}
path "sys/leases/renew" {
  capabilities = ["update"]
}
path "sys/leases/revoke" {
  capabilities = ["update"]
}
POLICY_EOF
  info "Policy 'dynamic-secrets' written to Vault"
fi

# Step 5: Create Kubernetes auth role for dynamic secrets
step "5/6: Creating Kubernetes auth role 'dynamic-secrets-role'..."
if $DRY_RUN; then
  info "[DRY-RUN] vault write auth/kubernetes/role/dynamic-secrets-role ..."
  info "  bound_service_account_names: securerag-app, external-secrets"
  info "  bound_service_account_namespaces: securerag-hub, external-secrets"
  info "  policies: dynamic-secrets"
  info "  ttl: 1h"
else
  kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault write auth/kubernetes/role/dynamic-secrets-role \
    bound_service_account_names="securerag-app,external-secrets" \
    bound_service_account_namespaces="securerag-hub,external-secrets" \
    policies="dynamic-secrets" \
    ttl=1h
  info "Auth role 'dynamic-secrets-role' created"
fi

# Step 6: Validate by generating temporary credentials
step "6/6: Validating dynamic credentials..."
if $DRY_RUN; then
  info "[DRY-RUN] vault read database/creds/securerag-app"
else
  CREDS=$(kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault read -format=json database/creds/securerag-app 2>/dev/null || true)
  if [ -n "${CREDS}" ]; then
    CRED_USERNAME=$(echo "${CREDS}" | jq -r '.data.username // "unknown"')
    CRED_PASSWORD=$(echo "${CREDS}" | jq -r '.data.password // "unknown"')
    CRED_LEASE_ID=$(echo "${CREDS}" | jq -r '.lease_id // "unknown"')
    CRED_DURATION=$(echo "${CREDS}" | jq -r '.data.ttl // "unknown"')

    echo ""
    info "═══════════════════════════════════════════════════════════"
    info "  DYNAMIC CREDENTIALS GENERATED SUCCESSFULLY"
    info "═══════════════════════════════════════════════════════════"
    info "  Username:      ${CRED_USERNAME}"
    info "  Password:      ${CRED_PASSWORD:0:8}... (masked)"
    info "  Lease ID:      ${CRED_LEASE_ID:0:16}... (masked)"
    info "  TTL:           ${CRED_DURATION}"
    info "═══════════════════════════════════════════════════════════"
    echo ""
  else
    warn "Validation generated no output — check Vault logs"
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  DYNAMIC SECRETS SETUP COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
info "  Next steps:"
info "    1. Deploy ExternalSecret: infra/k8s/secrets/external-secret-dynamic-db.yaml"
info "    2. Verify dynamic rotation: bash scripts/vault/rotate-dynamic-credentials.sh"
info "    3. Monitor: kubectl logs -n securerag-hub job/dynamic-secret-renewer"
echo ""
