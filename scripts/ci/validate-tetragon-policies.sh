#!/usr/bin/env bash
# validate-tetragon-policies.sh — Tetragon TracingPolicy Validation
# SecureRAG Hub — World-Class Runtime Security
#
# Validates Tetragon TracingPolicy YAML manifests.
#
# Usage:
#   bash scripts/ci/validate-tetragon-policies.sh
#
# Exit codes:
#   0 = All policies valid
#   1 = Invalid policies found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TETRAGON_DIR="${REPO_ROOT}/infra/k8s/tetragon"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
mkdir -p "${REPORT_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  TETRAGON — TRACINGPOLICY VALIDATION"
echo "═══════════════════════════════════════════════════════════════"

files=0
valid=0
invalid=0

for f in "${TETRAGON_DIR}"/*.yaml; do
  [ -f "${f}" ] || continue
  files=$((files + 1))
  name=$(basename "${f}")

  # Validate YAML syntax
  if python3 -c "import yaml; yaml.safe_load(open('${f}'))" 2>/dev/null; then
    info "  ✅ ${name} — YAML valid"
    valid=$((valid + 1))
  else
    error "  ❌ ${name} — YAML invalid"
    invalid=$((invalid + 1))
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESULTS: ${valid} valid, ${invalid} invalid (${files} files)"
echo "═══════════════════════════════════════════════════════════════"

{
  echo "# Tetragon TracingPolicy Validation — Summary"
  echo "_Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|:-----:|"
  echo "| Files | ${files} |"
  echo "| ✅ Valid | ${valid} |"
  echo "| ❌ Invalid | ${invalid} |"
} > "${REPORT_DIR}/tetragon-policy-validation.md"

[ "${invalid}" -eq 0 ] || exit 1
info "All Tetragon policies valid"
exit 0
