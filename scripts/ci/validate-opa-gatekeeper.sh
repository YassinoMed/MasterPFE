#!/usr/bin/env bash
# validate-opa-gatekeeper.sh — OPA Gatekeeper Policy Validation
# SecureRAG Hub — World-Class Policy-as-Code
#
# Uses conftest to validate Kubernetes manifests against Gatekeeper
# ConstraintTemplates (Rego policies). Blocks on violations.
#
# Usage:
#   bash scripts/ci/validate-opa-gatekeeper.sh
#
# Exit codes:
#   0 = All policies pass
#   1 = Rego violations found
#   2 = conftest not installed

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
GATEKEEPER_DIR="${GATEKEEPER_DIR:-infra/k8s/opa-gatekeeper}"
MANIFEST_DIRS=(
  "infra/k8s/base"
  "infra/k8s/overlays/demo"
  "infra/k8s/overlays/production"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

mkdir -p "${REPORT_DIR}"

# Check prerequisites
if ! command -v conftest &>/dev/null; then
  warn "conftest not installed. Attempting to install..."
  OPSYS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  [ "$ARCH" = "x86_64" ] && ARCH="amd64"
  curl -fsSL "https://github.com/open-policy-agent/conftest/releases/download/v0.57.0/conftest_0.57.0_${OPSYS}_${ARCH}.tar.gz" \
    | tar -xz -C /tmp conftest
  install -m 0755 /tmp/conftest /usr/local/bin/conftest
  info "conftest installed: $(conftest --version)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  OPA GATEKEEPER — POLICY VALIDATION"
echo "═══════════════════════════════════════════════════════════════"

TEMPLATES_DIR="${REPO_ROOT}/${GATEKEEPER_DIR}/templates"
POLICY_DIR="${REPO_ROOT}/${GATEKEEPER_DIR}/policies"

# Build Rego policy from ConstraintTemplates
mkdir -p "${POLICY_DIR}"

# Extract Rego from ConstraintTemplates
for tmpl in "${TEMPLATES_DIR}"/*.yaml; do
  name=$(basename "${tmpl}" .yaml)
  echo "[INFO] Extracting Rego from ${tmpl}"
  python3 - "${tmpl}" "${POLICY_DIR}/${name}.rego" <<'PYEOF'
import sys, yaml, re
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
rego_code = ""
for doc in (data if isinstance(data, list) else [data]):
    if doc and doc.get("kind") == "ConstraintTemplate":
        targets = doc.get("spec", {}).get("targets", [])
        for t in targets:
            rego_code = t.get("rego", "")
            break
with open(sys.argv[2], "w") as f:
    f.write(rego_code)
print(f"  Written to {sys.argv[2]}")
PYEOF
done

# Validate manifests against Rego policies
PASS=0
FAIL=0
SKIP=0

for dir in "${MANIFEST_DIRS[@]}"; do
  target="${REPO_ROOT}/${dir}"
  if [ ! -d "${target}" ]; then
    warn "Directory not found: ${target}"
    SKIP=$((SKIP + 1))
    continue
  fi

  info "Validating ${dir}..."

  # Find all YAML files
  manifests=$(find "${target}" -name "*.yaml" -o -name "*.yml" 2>/dev/null | head -50)
  if [ -z "${manifests}" ]; then
    warn "  No YAML files in ${dir}"
    SKIP=$((SKIP + 1))
    continue
  fi

  for manifest in ${manifests}; do
    if conftest test "${manifest}" --policy "${POLICY_DIR}" 2>/dev/null; then
      PASS=$((PASS + 1))
    else
      FAIL=$((FAIL + 1))
      error "  FAIL: ${manifest}"
    fi
  done
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESULTS: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "═══════════════════════════════════════════════════════════════"

# Generate report
{
  echo "# OPA Gatekeeper Validation — Summary"
  echo "_Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|:-----:|"
  echo "| ✅ Passed | ${PASS} |"
  echo "| ❌ Failed | ${FAIL} |"
  echo "| ⏭️  Skipped | ${SKIP} |"
  echo ""
  echo "**Status:** $([ "${FAIL}" -eq 0 ] && echo 'TERMINÉ' || echo 'PARTIEL')"
} > "${REPORT_DIR}/opa-gatekeeper-validation.md"

if [ "${FAIL}" -gt 0 ]; then
  error "OPA Gatekeeper validation FAILED — ${FAIL} violation(s) found"
  exit 1
fi

info "All OPA Gatekeeper policies validated successfully"
exit 0
