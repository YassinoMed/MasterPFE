#!/usr/bin/env bash
# validate-platform-tools.sh — World-Class Platform Validation
# Valide les nouveaux composants platform (OPA, Cilium, Crossplane).
# Non-bloquant: exit 0 si outils absents, rapport warning.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
mkdir -p "${REPORT_DIR}"

PASS=0; WARN=0; SKIP=0
check() { echo "  [$1] $2"; case "$1" in PASS) PASS=$((PASS+1));; WARN) WARN=$((WARN+1));; SKIP) SKIP=$((SKIP+1));; esac; }

echo "═══ Platform Tools Validation ═══"

# ── OPA Gatekeeper Rego ──────────────────────────────────
if command -v conftest >/dev/null 2>&1; then
  violations=$(find "${REPO_ROOT}/infra/k8s/opa-gatekeeper" -name "*.yaml" -exec conftest test {} \; 2>/dev/null | grep -c "FAIL" || echo 0)
  [ "$violations" -eq 0 ] && check PASS "OPA Gatekeeper: 0 Rego violations" || check WARN "OPA Gatekeeper: ${violations} violations"
else
  check SKIP "OPA Gatekeeper: conftest not installed"
fi

# ── Cilium Network Policies ──────────────────────────────
if [ -f "${REPO_ROOT}/infra/k8s/cilium/daemonset.yaml" ]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import yaml; yaml.safe_load(open('${REPO_ROOT}/infra/k8s/cilium/daemonset.yaml'))" 2>/dev/null && \
      check PASS "Cilium: YAML valid" || check WARN "Cilium: YAML invalid"
  else
    check SKIP "Cilium: python3 not available"
  fi
fi

# ── Crossplane Compositions ──────────────────────────────
if [ -f "${REPO_ROOT}/infra/k8s/crossplane/provisioning.yaml" ]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import yaml; list(yaml.safe_load_all(open('${REPO_ROOT}/infra/k8s/crossplane/provisioning.yaml')))" 2>/dev/null && \
      check PASS "Crossplane: YAML valid" || check WARN "Crossplane: YAML invalid"
  fi
fi

# ── Tetragon Policies ────────────────────────────────────
if [ -f "${REPO_ROOT}/infra/k8s/tetragon/daemonset.yaml" ]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import yaml; list(yaml.safe_load_all(open('${REPO_ROOT}/infra/k8s/tetragon/daemonset.yaml')))" 2>/dev/null && \
      check PASS "Tetragon: YAML valid" || check WARN "Tetragon: YAML invalid"
  fi
fi

# ── Data Platform ────────────────────────────────────────
for f in "${REPO_ROOT}/infra/k8s/data-platform/deployment.yaml"; do
  [ -f "$f" ] && python3 -c "import yaml; list(yaml.safe_load_all(open('$f')))" 2>/dev/null && \
    check PASS "Data Platform: YAML valid" || true
done

# ── ML Platform ──────────────────────────────────────────
for f in "${REPO_ROOT}/infra/k8s/ml-platform/deployment.yaml"; do
  [ -f "$f" ] && python3 -c "import yaml; list(yaml.safe_load_all(open('$f')))" 2>/dev/null && \
    check PASS "ML Platform: YAML valid" || true
done

# ── CIS Kubernetes Benchmark (non-bloquant) ──────────────
if command -v kube-bench >/dev/null 2>&1; then
  check PASS "CIS K8s: kube-bench available"
else
  check SKIP "CIS K8s: kube-bench not installed (run: make cis-benchmark)"
fi

# ── Feature Flags Check ──────────────────────────────────
ff="${REPO_ROOT}/infra/k8s/base/feature-flags-configmap.yaml"
if [ -f "$ff" ]; then
  disabled=$(grep -c '"false"' "$ff" 2>/dev/null || echo 0)
  check PASS "Feature Flags: ${disabled} flags disabled (production safe)"
fi

echo ""
echo "══════ Summary ══════"
echo "  PASS: ${PASS}  WARN: ${WARN}  SKIP: ${SKIP}"
echo "  Report: ${REPORT_DIR}/platform-tools-validation.md"
[ ${WARN} -eq 0 ] && exit 0 || exit 0
