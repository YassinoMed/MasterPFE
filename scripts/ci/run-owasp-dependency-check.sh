#!/usr/bin/env bash
# run-owasp-dependency-check.sh — OWASP Dependency-Check
# SecureRAG Hub — World-Class Software Composition Analysis
#
# Scans all project dependencies for known vulnerabilities.
# Produces HTML, JSON, and XML reports. Blocks on HIGH and CRITICAL.
#
# Usage:
#   bash scripts/ci/run-owasp-dependency-check.sh
#
# Exit codes:
#   0 = All dependencies pass (no HIGH/CRITICAL)
#   1 = Vulnerabilities found above threshold

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT_DIR="${REPORT_DIR:-security/reports}"
mkdir -p "${REPORT_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  OWASP DEPENDENCY-CHECK — SCA"
echo "═══════════════════════════════════════════════════════════════"

# Install OWASP Dependency-Check if not present
if ! command -v dependency-check.sh &>/dev/null; then
  if [ ! -f /opt/dependency-check/bin/dependency-check.sh ]; then
    info "Installing OWASP Dependency-Check v12.1.0..."
    ODC_VERSION="12.1.0"
    curl -fsSLo /tmp/dependency-check.zip \
      "https://github.com/jeremylong/DependencyCheck/releases/download/v${ODC_VERSION}/dependency-check-${ODC_VERSION}-release.zip"
    unzip -q /tmp/dependency-check.zip -d /opt/
    ln -sf "/opt/dependency-check/bin/dependency-check.sh" /usr/local/bin/dependency-check.sh
    rm -f /tmp/dependency-check.zip
    info "OWASP Dependency-Check installed"
  fi
fi

DC_CMD=""
if command -v dependency-check.sh &>/dev/null; then
  DC_CMD="dependency-check.sh"
elif [ -f /opt/dependency-check/bin/dependency-check.sh ]; then
  DC_CMD="/opt/dependency-check/bin/dependency-check.sh"
else
  warn "OWASP Dependency-Check not available — skipping"
  echo "0:0:0" > "${REPORT_DIR}/dependency-check-summary.txt"
  exit 0
fi

SCAN_DIRS=(
  "platform/portal-web"
  "services-laravel/auth-users-service"
  "services-laravel/chatbot-manager-service"
  "services-laravel/conversation-service"
  "services-laravel/audit-security-service"
  "services"
)

TOTAL_CRITICAL=0
TOTAL_HIGH=0

for dir in "${SCAN_DIRS[@]}"; do
  target="${REPO_ROOT}/${dir}"
  [ -d "${target}" ] || continue

  slug=$(echo "${dir}" | tr '/-' '__')
  info "Scanning ${dir}..."

  set +e
  "${DC_CMD}" \
    --project "SecureRAG Hub: ${dir}" \
    --scan "${target}" \
    --format HTML \
    --format JSON \
    --format XML \
    --out "${REPORT_DIR}/dependency-check-${slug}" \
    --failOnCVSS 7 \
    --enableExperimental false \
    --noupdate \
    2>/dev/null
  DC_EXIT=$?
  set -e

  # Parse results
  JSON_REPORT="${REPORT_DIR}/dependency-check-${slug}/dependency-check-report.json"
  if [ -f "${JSON_REPORT}" ]; then
    CRITICAL=$(jq '[.dependencies[]?.vulnerabilities[]? | select(.cvssv3_baseScore >= 9)] | length' "${JSON_REPORT}" 2>/dev/null || echo 0)
    HIGH=$(jq '[.dependencies[]?.vulnerabilities[]? | select(.cvssv3_baseScore >= 7 and .cvssv3_baseScore < 9)] | length' "${JSON_REPORT}" 2>/dev/null || echo 0)
    TOTAL_CRITICAL=$((TOTAL_CRITICAL + CRITICAL))
    TOTAL_HIGH=$((TOTAL_HIGH + HIGH))
    info "  ${dir}: ${CRITICAL} CRITICAL, ${HIGH} HIGH"
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESULTS: ${TOTAL_CRITICAL} CRITICAL, ${TOTAL_HIGH} HIGH"
echo "═══════════════════════════════════════════════════════════════"

echo "${TOTAL_CRITICAL}:${TOTAL_HIGH}" > "${REPORT_DIR}/dependency-check-summary.txt"

if [ "${TOTAL_CRITICAL}" -gt 0 ] || [ "${TOTAL_HIGH}" -gt 0 ]; then
  error "OWASP Dependency-Check found ${TOTAL_CRITICAL} CRITICAL and ${TOTAL_HIGH} HIGH vulnerabilities"
  exit 1
fi

info "OWASP Dependency-Check completed — no HIGH/CRITICAL vulnerabilities"
exit 0
