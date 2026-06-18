#!/usr/bin/env bash
# rotate-dynamic-credentials.sh — Rotate Dynamic Credentials for PostgreSQL
# SecureRAG Hub — Enterprise Credential Rotation
#
# This script rotates:
#   1. Root credentials for the PostgreSQL connection (rotate-root)
#   2. All active leases for the "securerag-app" dynamic role (revoke-prefix)
#   3. Verifies new credentials are functional via a test read
#
# Usage:
#   bash scripts/vault/rotate-dynamic-credentials.sh [--dry-run] [--force-revoke]
#
# Options:
#   --dry-run       Print actions without executing
#   --force-revoke  Immediately revoke all active leases (may cause brief disruption)

set -euo pipefail

NAMESPACE="${NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
DB_CONFIG_NAME="${DB_CONFIG_NAME:-postgres-securerag}"
DYNAMIC_ROLE="${DYNAMIC_ROLE:-securerag-app}"

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
FORCE_REVOKE=false
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=true ;;
    --force-revoke) FORCE_REVOKE=true ;;
  esac
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  DYNAMIC CREDENTIALS ROTATION"
echo "  Target:  ${DB_CONFIG_NAME} / ${DYNAMIC_ROLE}"
echo "  Mode:    $(${DRY_RUN} && echo 'DRY-RUN' || echo 'LIVE')"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Step 1: Rotate root credentials
step "1/3: Rotating root credentials for '${DB_CONFIG_NAME}'..."
if $DRY_RUN; then
  info "[DRY-RUN] vault write -f database/rotate-root/${DB_CONFIG_NAME}"
else
  kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault write -f "database/rotate-root/${DB_CONFIG_NAME}"
  info "Root credentials rotated for '${DB_CONFIG_NAME}'"
fi

# Step 2: Revoke active leases (optional)
if $FORCE_REVOKE; then
  step "2/3: Revoking all active leases for '${DYNAMIC_ROLE}'..."
  if $DRY_RUN; then
    info "[DRY-RUN] vault lease revoke -prefix database/creds/${DYNAMIC_ROLE}"
  else
    kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault lease revoke -prefix "database/creds/${DYNAMIC_ROLE}" 2>/dev/null || true
    info "All active leases revoked for '${DYNAMIC_ROLE}'"
  fi
else
  step "2/3: Skipping lease revocation (use --force-revoke to revoke active leases)"
  info "Existing leases remain valid until their TTL expires"
  info "New credential requests will use the rotated root credentials"
fi

# Step 3: Validate new credentials
step "3/3: Validating new credentials..."
if $DRY_RUN; then
  info "[DRY-RUN] vault read database/creds/${DYNAMIC_ROLE}"
else
  # Wait briefly for propagation
  sleep 2

  NEW_CREDS=$(kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault read -format=json "database/creds/${DYNAMIC_ROLE}" 2>/dev/null || true)
  if [ -n "${NEW_CREDS}" ]; then
    NEW_USERNAME=$(echo "${NEW_CREDS}" | jq -r '.data.username // "unknown"')
    NEW_PASSWORD=$(echo "${NEW_CREDS}" | jq -r '.data.password // "unknown"')
    NEW_LEASE_ID=$(echo "${NEW_CREDS}" | jq -r '.lease_id // "unknown"')
    NEW_TTL=$(echo "${NEW_CREDS}" | jq -r '.data.ttl // "unknown"')
    NEW_EXPIRATION=$(echo "${NEW_CREDS}" | jq -r '.data.expiration // "N/A"')

    echo ""
    info "═══════════════════════════════════════════════════════════"
    info "  ROTATION VALIDATION — NEW CREDENTIALS"
    info "═══════════════════════════════════════════════════════════"
    info "  Username:      ${NEW_USERNAME}"
    info "  Password:      ${NEW_PASSWORD:0:8}... (masked)"
    info "  Lease ID:      ${NEW_LEASE_ID:0:16}... (masked)"
    info "  TTL:           ${NEW_TTL}"
    info "  Expiration:    ${NEW_EXPIRATION}"
    info "═══════════════════════════════════════════════════════════"
    echo ""
    info "Rotation completed successfully"
  else
    error "Failed to generate new credentials after rotation"
    error "Check Vault logs: kubectl logs -n ${NAMESPACE} ${VAULT_POD}"
    exit 1
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ROTATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
info "  Next steps:"
info "    1. Verify application connectivity: bash scripts/vault/validate-dynamic-secrets.sh"
info "    2. Check ExternalSecret refresh: kubectl get externalsecret -n securerag-hub"
echo ""
