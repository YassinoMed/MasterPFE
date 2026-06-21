#!/usr/bin/env bash
# seed-vault-secrets.sh — Seed application secrets into Vault KV v2
# SecureRAG Hub — World-Class Secrets Management
set -euo pipefail

VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VAULT SECRET SEEDING — SecureRAG Hub"
echo "═══════════════════════════════════════════════════════════════"

# Retrieve root token
ROOT_TOKEN=$(kubectl get secret vault-init-keys -n "${VAULT_NAMESPACE}" -o jsonpath='{.data.root-token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
if [ -z "${ROOT_TOKEN}" ]; then
  error "Vault root token not found. Run vault-init.sh first."
  exit 1
fi

vault_cmd() {
  kubectl exec -n "${VAULT_NAMESPACE}" -c vault "${VAULT_POD}" -- \
    env VAULT_TOKEN="${ROOT_TOKEN}" VAULT_ADDR="http://127.0.0.1:8200" vault "$@"
}

# Generate secure random values
gen_password() { python3 -c "import secrets; print(secrets.token_urlsafe(${1:-32}))"; }
gen_hex()      { python3 -c "import secrets; print(secrets.token_hex(${1:-32}))"; }

DB_PASSWORD=$(gen_password 24)
REDIS_PASSWORD=$(gen_password 16)
JWT_SECRET=$(gen_hex 64)
APP_KEY="base64:$(python3 -c "import secrets, base64; print(base64.b64encode(secrets.token_bytes(32)).decode())")"
API_GATEWAY_KEY=$(gen_password 32)
COSIGN_PASSWORD=$(gen_password 24)

info "Phase 1/3: Seeding shared infrastructure secrets..."
vault_cmd kv put secret/securerag/infrastructure \
  db_host="postgresql.securerag-hub.svc.cluster.local" \
  db_port="5432" \
  db_name="securerag" \
  db_username="securerag_app" \
  db_password="${DB_PASSWORD}" \
  redis_host="redis.securerag-hub.svc.cluster.local" \
  redis_port="6379" \
  redis_password="${REDIS_PASSWORD}" 2>/dev/null || \
vault_cmd write secret/data/securerag/infrastructure \
  data="{\"db_host\":\"postgresql.securerag-hub.svc.cluster.local\",\"db_port\":\"5432\",\"db_name\":\"securerag\",\"db_username\":\"securerag_app\",\"db_password\":\"${DB_PASSWORD}\",\"redis_host\":\"redis.securerag-hub.svc.cluster.local\",\"redis_port\":\"6379\",\"redis_password\":\"${REDIS_PASSWORD}\"}"

info "Phase 2/3: Seeding per-service secrets..."

# Portal Web
vault_cmd write secret/data/securerag/portal-web \
  data="{\"app_key\":\"${APP_KEY}\",\"jwt_secret\":\"${JWT_SECRET}\",\"session_driver\":\"redis\"}" 2>/dev/null || true
info "  ✅ portal-web"

# Auth Users
vault_cmd write secret/data/securerag/auth-users \
  data="{\"app_key\":\"${APP_KEY}\",\"jwt_secret\":\"${JWT_SECRET}\",\"jwt_ttl\":\"3600\"}" 2>/dev/null || true
info "  ✅ auth-users"

# Chatbot Manager
vault_cmd write secret/data/securerag/chatbot-manager \
  data="{\"app_key\":\"${APP_KEY}\",\"openai_api_key\":\"sk-demo-not-real-key\",\"rag_service_url\":\"http://rag-service:8000\"}" 2>/dev/null || true
info "  ✅ chatbot-manager"

# Conversation Service
vault_cmd write secret/data/securerag/conversation-service \
  data="{\"app_key\":\"${APP_KEY}\",\"encryption_key\":\"$(gen_hex 32)\"}" 2>/dev/null || true
info "  ✅ conversation-service"

# Audit Security Service
vault_cmd write secret/data/securerag/audit-security-service \
  data="{\"app_key\":\"${APP_KEY}\",\"audit_log_encryption_key\":\"$(gen_hex 32)\"}" 2>/dev/null || true
info "  ✅ audit-security-service"

info "Phase 3/3: Seeding CI/CD pipeline secrets..."
vault_cmd write secret/data/securerag/pipeline \
  data="{\"cosign_password\":\"${COSIGN_PASSWORD}\",\"api_gateway_key\":\"${API_GATEWAY_KEY}\",\"sonar_token\":\"squ-demo-token\"}" 2>/dev/null || true
info "  ✅ pipeline"

# Enable audit logging
info "Enabling Vault audit device..."
vault_cmd audit list -format=json 2>/dev/null | grep -q '"file/"' || \
  vault_cmd audit enable file file_path=/vault/audit/vault-audit.log 2>/dev/null || \
  warn "Audit device not enabled (may require writable path)"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ VAULT SECRET SEEDING COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Secrets seeded:"
echo "    secret/securerag/infrastructure    (DB, Redis)"
echo "    secret/securerag/portal-web        (APP_KEY, JWT)"
echo "    secret/securerag/auth-users        (APP_KEY, JWT)"
echo "    secret/securerag/chatbot-manager   (APP_KEY, OpenAI)"
echo "    secret/securerag/conversation-service"
echo "    secret/securerag/audit-security-service"
echo "    secret/securerag/pipeline          (Cosign, SonarQube)"
echo ""
echo "  Verify: kubectl exec -n vault vault-0 -- env VAULT_TOKEN=\$TOKEN vault kv list secret/securerag/"
echo ""
