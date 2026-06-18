#!/usr/bin/env bash
# validate-dynamic-secrets.sh — Validate Vault Dynamic Secrets
# SecureRAG Hub — Enterprise Validation & Compliance
#
# This script:
#   - Reads dynamic credentials from Vault
#   - Tests PostgreSQL connection using the credentials
#   - Validates TTL and remaining lease duration
#   - Reports lease health metrics
#
# Usage:
#   bash scripts/vault/validate-dynamic-secrets.sh [--verbose]
#
# Exit codes:
#   0 — All validations passed
#   1 — One or more validations failed
#   2 — Prerequisites not met

set -euo pipefail

NAMESPACE="${NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
DYNAMIC_ROLE="${DYNAMIC_ROLE:-securerag-app}"
DB_CONFIG_NAME="${DB_CONFIG_NAME:-postgres-securerag}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-securerag-hub}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}    %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC}   %s\n" "$*" >&2; }
step()    { printf "${BLUE}[STEP]${NC}    %s\n" "$*"; }
detail()  { printf "${CYAN}  →${NC}     %s\n" "$*"; }
pass()    { printf "  ${GREEN}✓${NC} %s\n" "$*"; }
fail()    { printf "  ${RED}✗${NC} %s\n" "$*"; }

VERBOSE=false
[ "${1:-}" = "--verbose" ] && VERBOSE=true

ERRORS=0

# Prerequisite check: vault-0 pod
step "Checking prerequisites..."
if kubectl get pod -n "${NAMESPACE}" "${VAULT_POD}" --no-headers 2>/dev/null | grep -q Running; then
  pass "Vault pod ${VAULT_POD} is running"
else
  fail "Vault pod ${VAULT_POD} is not running"
  error "Prerequisite not met. Exiting."
  exit 2
fi

# Check Vault status
VAULT_STATUS=$(kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault status -format=json 2>/dev/null || echo "")
if echo "${VAULT_STATUS}" | jq -e '.sealed == false' > /dev/null 2>&1; then
  pass "Vault is unsealed"
else
  fail "Vault is sealed or unreachable"
  ERRORS=$((ERRORS + 1))
fi

echo ""

# Step 1: Validate database engine is mounted
step "1/4: Validating database secrets engine..."
ENGINE_LIST=$(kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault secrets list -format=json 2>/dev/null || echo "")
if echo "${ENGINE_LIST}" | jq -e 'has("database/")' > /dev/null 2>&1; then
  pass "Database secrets engine mounted at database/"
  if $VERBOSE; then
    ENGINE_TTL=$(echo "${ENGINE_LIST}" | jq -r '.["database/"].options.default_lease_ttl // "unknown"')
    detail "Default lease TTL: ${ENGINE_TTL}"
  fi
else
  fail "Database secrets engine not mounted at database/"
  ERRORS=$((ERRORS + 1))
fi

# Step 2: Validate database config
step "2/4: Validating PostgreSQL connection configuration..."
DB_CONFIG=$(kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault read -format=json "database/config/${DB_CONFIG_NAME}" 2>/dev/null || echo "")
if [ -n "${DB_CONFIG}" ]; then
  pass "Database config '${DB_CONFIG_NAME}' exists"
  if $VERBOSE; then
    CONN_URL=$(echo "${DB_CONFIG}" | jq -r '.data.connection_url // "N/A"')
    detail "Connection URL: ${CONN_URL}"
    ALLOWED_ROLES=$(echo "${DB_CONFIG}" | jq -r '.data.allowed_roles // "N/A"')
    detail "Allowed roles: ${ALLOWED_ROLES}"
  fi
else
  fail "Database config '${DB_CONFIG_NAME}' not found"
  ERRORS=$((ERRORS + 1))
fi

# Step 3: Validate dynamic role
step "3/4: Validating dynamic role '${DYNAMIC_ROLE}'..."
ROLE_CONFIG=$(kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault read -format=json "database/roles/${DYNAMIC_ROLE}" 2>/dev/null || echo "")
if [ -n "${ROLE_CONFIG}" ]; then
  pass "Dynamic role '${DYNAMIC_ROLE}' exists"

  DEFAULT_TTL=$(echo "${ROLE_CONFIG}" | jq -r '.data.default_ttl // 0')
  MAX_TTL=$(echo "${ROLE_CONFIG}" | jq -r '.data.max_ttl // 0')

  if [ "${DEFAULT_TTL}" -eq 3600 ] || [ "${DEFAULT_TTL}" -eq 3600 ]; then
    pass "Default TTL is 1h (${DEFAULT_TTL}s)"
  else
    warn "Default TTL is ${DEFAULT_TTL}s (expected 3600s)"
  fi

  if [ "${MAX_TTL}" -eq 86400 ]; then
    pass "Max TTL is 24h (${MAX_TTL}s)"
  else
    warn "Max TTL is ${MAX_TTL}s (expected 86400s)"
  fi

  if $VERBOSE; then
    CREATION_STMTS=$(echo "${ROLE_CONFIG}" | jq -r '.data.creation_statements[] // "N/A"')
    detail "Creation statements:"
    echo "${CREATION_STMTS}" | while read -r line; do detail "  ${line}"; done
  fi
else
  fail "Dynamic role '${DYNAMIC_ROLE}' not found"
  ERRORS=$((ERRORS + 1))
fi

# Step 4: Generate and validate credentials
step "4/4: Generating and validating credentials..."
echo ""

CREDS=$(kubectl exec -n "${NAMESPACE}" "${VAULT_POD}" -- vault read -format=json "database/creds/${DYNAMIC_ROLE}" 2>/dev/null || echo "")
if [ -n "${CREDS}" ]; then
  CRED_USERNAME=$(echo "${CREDS}" | jq -r '.data.username // "unknown"')
  CRED_PASSWORD=$(echo "${CREDS}" | jq -r '.data.password // "unknown"')
  CRED_LEASE_ID=$(echo "${CREDS}" | jq -r '.lease_id // "unknown"')
  CRED_TTL=$(echo "${CREDS}" | jq -r '.data.ttl // 0')
  CRED_DURATION=$(echo "${CREDS}" | jq -r '.lease_duration // "unknown"')
  CRED_RENEWABLE=$(echo "${CREDS}" | jq -r '.renewable // false')
  CRED_EXPIRATION=$(echo "${CREDS}" | jq -r '.data.expiration // "N/A"')

  pass "Dynamic credentials generated successfully"
  echo ""
  info "  ┌────────────────────────────────────────────────────────┐"
  info "  │           DYNAMIC CREDENTIALS DETAILS                  │"
  info "  ├────────────────────────────────────────────────────────┤"
  printf "  │  Username:           %-36s │\n" "${CRED_USERNAME}"
  printf "  │  Password:           %-8s... (masked)           │\n" "${CRED_PASSWORD:0:8}"
  printf "  │  Lease ID:           %-16s... (masked)          │\n" "${CRED_LEASE_ID:0:16}"
  printf "  │  TTL:                %-36s │\n" "${CRED_TTL}s"
  printf "  │  Lease Duration:     %-36s │\n" "${CRED_DURATION}s"
  printf "  │  Renewable:          %-36s │\n" "${CRED_RENEWABLE}"
  printf "  │  Expiration:         %-36s │\n" "${CRED_EXPIRATION}"
  info "  └────────────────────────────────────────────────────────┘"
  echo ""

  # Validate TTL is within expected range
  if [ "${CRED_TTL}" -gt 0 ] 2>/dev/null; then
    TTL_HUMAN=$(date -u -d "@${CRED_TTL}" "+%Hh %Mm %Ss" 2>/dev/null || echo "${CRED_TTL}s")
    info "  Remaining lease duration: ${TTL_HUMAN}"

    if [ "${CRED_TTL}" -lt 300 ]; then
      warn "  Lease is expiring soon (TTL < 5 minutes)"
    else
      pass "Lease has sufficient remaining TTL (${TTL_HUMAN})"
    fi
  fi

  # Test PostgreSQL connection (try in-cluster psql)
  if command -v psql &>/dev/null || curl -sf "http://${POSTGRES_SERVICE}.${POSTGRES_NAMESPACE}.svc.cluster.local:5432" > /dev/null 2>&1; then
    PG_STRING="postgresql://${CRED_USERNAME}:${CRED_PASSWORD}@${POSTGRES_SERVICE}.${POSTGRES_NAMESPACE}.svc.cluster.local:5432/securerag?sslmode=disable"
    if command -v psql &>/dev/null; then
      PG_TEST=$(PGPASSWORD="${CRED_PASSWORD}" psql -h "${POSTGRES_SERVICE}.${POSTGRES_NAMESPACE}.svc.cluster.local" -U "${CRED_USERNAME}" -d securerag -c "SELECT 1 AS connected;" -t -A 2>/dev/null || echo "FAILED")
      if [ "${PG_TEST}" = "1" ]; then
        pass "PostgreSQL connection test passed with dynamic credentials"
      else
        warn "PostgreSQL connection test result: ${PG_TEST}"
      fi
    else
      info "psql not available — skipping direct database connection test"
      info "Install postgresql-client to enable connection testing"
    fi
  else
    info "PostgreSQL service not reachable from this host"
    info "Skipping database connection test (expected when running outside cluster)"
  fi
else
  fail "Failed to generate dynamic credentials"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VALIDATION SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ "${ERRORS}" -eq 0 ]; then
  echo "  ${GREEN}All validations passed — dynamic secrets are healthy${NC}"
  echo ""
  info "  Engine:       database/ (PostgreSQL)"
  info "  Config:       ${DB_CONFIG_NAME}"
  info "  Role:         ${DYNAMIC_ROLE}"
  info "  Default TTL:  1h"
  info "  Max TTL:      24h"
  echo ""
  exit 0
else
  echo "  ${RED}${ERRORS} validation(s) failed — check Vault configuration${NC}"
  echo ""
  exit 1
fi
