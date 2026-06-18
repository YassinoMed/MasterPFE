#!/usr/bin/env bash
# run-hadolint.sh — Dockerfile Linting
# SecureRAG Hub — World-Class Container Security
#
# Scans all Dockerfiles with Hadolint and produces JUnit XML report.
# Blocks on ERROR-level findings.
#
# Usage:
#   bash scripts/ci/run-hadolint.sh
#
# Exit codes:
#   0 = All Dockerfiles pass
#   1 = Hadolint violations found

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
echo "  HADOLINT — DOCKERFILE LINTING"
echo "═══════════════════════════════════════════════════════════════"

# Install hadolint if not present
if ! command -v hadolint &>/dev/null; then
  info "Installing hadolint..."
  HADOLINT_VERSION="2.12.0"
  ARCH=$(uname -m)
  [ "$ARCH" = "x86_64" ] && ARCH="x86_64"
  curl -fsSLo /usr/local/bin/hadolint \
    "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-${ARCH}"
  chmod +x /usr/local/bin/hadolint
  info "hadolint installed: $(hadolint --version)"
fi

# Find all Dockerfiles
DOCKERFILES=$(find "${REPO_ROOT}" -name "Dockerfile" -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/.git/*' 2>/dev/null | sort)

if [ -z "${DOCKERFILES}" ]; then
  warn "No Dockerfiles found"
  exit 0
fi

echo ""
info "Found $(echo "${DOCKERFILES}" | wc -l) Dockerfiles"
echo ""

PASS=0
FAIL=0
TOTAL=0

# JUnit XML report header
JUNIT_XML="${REPORT_DIR}/hadolint-junit.xml"
cat > "${JUNIT_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="hadolint" tests="__COUNT__" failures="__FAILURES__">
EOF

HADOLINT_VIOLATIONS=""

for dockerfile in ${DOCKERFILES}; do
  TOTAL=$((TOTAL + 1))
  rel_path="${dockerfile#${REPO_ROOT}/}"
  echo "  [${TOTAL}] ${rel_path}"

  # Run hadolint (JSON output for parsing)
  violations=$(hadolint --format json "${dockerfile}" 2>/dev/null || true)
  violation_count=$(echo "${violations}" | jq 'length' 2>/dev/null || echo 0)

  if [ "${violation_count}" -eq 0 ]; then
    echo "    ✅ PASS — 0 violations"
    PASS=$((PASS + 1))
  else
    echo "    ❌ FAIL — ${violation_count} violation(s)"
    FAIL=$((FAIL + 1))
    HADOLINT_VIOLATIONS="${HADOLINT_VIOLATIONS}  - ${rel_path}: ${violation_count} violations"$'\n'

    # Append JUnit test case for each violation
    echo "${violations}" | jq -c '.[]' 2>/dev/null | while read -r v; do
      line=$(echo "${v}" | jq -r '.line // 0')
      code=$(echo "${v}" | jq -r '.code // "unknown"')
      msg=$(echo "${v}" | jq -r '.message // ""' | sed 's/"/\&quot;/g')
      cat >> "${JUNIT_XML}" << TESTEOF
  <testcase name="hadolint: ${code}" classname="${rel_path}" line="${line}">
    <failure message="${msg}">${code} at ${rel_path}:${line}</failure>
  </testcase>
TESTEOF
    done
  fi
done

# Close JUnit XML
echo '</testsuite>' >> "${JUNIT_XML}"

# Update counts in JUnit XML
sed -i "s/__COUNT__/${TOTAL}/; s/__FAILURES__/${FAIL}/" "${JUNIT_XML}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESULTS: ${PASS} passed, ${FAIL} failed (${TOTAL} total)"
echo "  JUnit: ${JUNIT_XML}"
echo "═══════════════════════════════════════════════════════════════"

if [ -n "${HADOLINT_VIOLATIONS}" ]; then
  echo ""
  echo "VIOLATIONS:" >&2
  echo "${HADOLINT_VIOLATIONS}" >&2
fi

[ "${FAIL}" -eq 0 ] || exit 1
exit 0
