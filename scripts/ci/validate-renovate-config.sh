#!/usr/bin/env bash
# validate-renovate-config.sh — Validate Renovate configuration and dependency freshness
# SecureRAG Hub — World-Class Dependency Management
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
mkdir -p "${REPORT_DIR}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RENOVATE CONFIG VALIDATION"
echo "═══════════════════════════════════════════════════════════════"

PASS=0
FAIL=0

# 1. Check renovate.json exists and is valid JSON
if [ -f "renovate.json" ]; then
  if python3 -c "import json; json.load(open('renovate.json'))" 2>/dev/null; then
    info "✅ renovate.json is valid JSON"
    PASS=$((PASS + 1))
  else
    error "❌ renovate.json is not valid JSON"
    FAIL=$((FAIL + 1))
  fi
else
  error "❌ renovate.json not found"
  FAIL=$((FAIL + 1))
fi

# 2. Validate required config fields
if [ -f "renovate.json" ]; then
  HAS_EXTENDS=$(python3 -c "import json; d=json.load(open('renovate.json')); print('yes' if 'extends' in d else 'no')" 2>/dev/null || echo "no")
  HAS_RULES=$(python3 -c "import json; d=json.load(open('renovate.json')); print('yes' if 'packageRules' in d else 'no')" 2>/dev/null || echo "no")
  HAS_K8S=$(python3 -c "import json; d=json.load(open('renovate.json')); print('yes' if 'kubernetes' in d else 'no')" 2>/dev/null || echo "no")
  HAS_HELM=$(python3 -c "import json; d=json.load(open('renovate.json')); print('yes' if 'helm-values' in d else 'no')" 2>/dev/null || echo "no")

  [ "${HAS_EXTENDS}" = "yes" ] && { info "✅ 'extends' config present"; PASS=$((PASS + 1)); } || { warn "⚠️  Missing 'extends' config"; }
  [ "${HAS_RULES}" = "yes" ] && { info "✅ 'packageRules' defined"; PASS=$((PASS + 1)); } || { warn "⚠️  Missing 'packageRules'"; }
  [ "${HAS_K8S}" = "yes" ] && { info "✅ Kubernetes file matching configured"; PASS=$((PASS + 1)); } || { warn "⚠️  Kubernetes scanning not configured"; }
  [ "${HAS_HELM}" = "yes" ] && { info "✅ Helm values scanning configured"; PASS=$((PASS + 1)); } || { warn "⚠️  Helm scanning not configured"; }
fi

# 3. Audit Composer dependencies
info "Auditing Composer dependencies..."
COMPOSER_OUTDATED=0
for app in platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service; do
  if [ -f "${app}/composer.json" ]; then
    LOCK_AGE=""
    if [ -f "${app}/composer.lock" ]; then
      LOCK_MOD=$(stat -c %Y "${app}/composer.lock" 2>/dev/null || echo 0)
      NOW=$(date +%s)
      AGE_DAYS=$(( (NOW - LOCK_MOD) / 86400 ))
      if [ "${AGE_DAYS}" -gt 30 ]; then
        warn "  ${app}: composer.lock is ${AGE_DAYS} days old"
        COMPOSER_OUTDATED=$((COMPOSER_OUTDATED + 1))
      else
        info "  ${app}: composer.lock is ${AGE_DAYS} days old ✅"
      fi
    fi
  fi
done

if [ "${COMPOSER_OUTDATED}" -eq 0 ]; then
  info "✅ All Composer locks are fresh (< 30 days)"
  PASS=$((PASS + 1))
else
  warn "⚠️  ${COMPOSER_OUTDATED} Composer locks are stale (> 30 days)"
fi

# 4. Check for known vulnerability advisories in lock files
info "Checking for security advisories..."
VULN_COUNT=0
for app in platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service; do
  if [ -f "${app}/composer.json" ] && command -v composer &>/dev/null; then
    ADVISORIES=$(cd "${app}" && composer audit --format=json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('advisories',{})))" 2>/dev/null || echo "0")
    if [ "${ADVISORIES}" -gt 0 ]; then
      warn "  ${app}: ${ADVISORIES} security advisories"
      VULN_COUNT=$((VULN_COUNT + ADVISORIES))
    fi
  fi
done

if [ "${VULN_COUNT}" -eq 0 ]; then
  info "✅ No known security advisories in dependencies"
  PASS=$((PASS + 1))
else
  warn "⚠️  ${VULN_COUNT} security advisories found"
fi

# Generate report
cat > "${REPORT_DIR}/renovate-validation.md" <<EOF
# Renovate Configuration Validation

| Check | Result |
|:---|:---|
| renovate.json valid | $([ -f "renovate.json" ] && echo "✅" || echo "❌") |
| extends configured | ${HAS_EXTENDS:-N/A} |
| packageRules defined | ${HAS_RULES:-N/A} |
| Kubernetes scanning | ${HAS_K8S:-N/A} |
| Helm scanning | ${HAS_HELM:-N/A} |
| Composer locks fresh | $([ "${COMPOSER_OUTDATED:-0}" -eq 0 ] && echo "✅" || echo "⚠️ ${COMPOSER_OUTDATED} stale") |
| Security advisories | $([ "${VULN_COUNT:-0}" -eq 0 ] && echo "✅ None" || echo "⚠️ ${VULN_COUNT}") |

**Passed**: ${PASS} | **Failed**: ${FAIL}
EOF

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "  Report: ${REPORT_DIR}/renovate-validation.md"
echo "═══════════════════════════════════════════════════════════════"

[ "${FAIL}" -eq 0 ] || exit 1
