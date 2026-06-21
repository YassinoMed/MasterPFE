#!/usr/bin/env bash
# secure-quality-gate.sh — Secure Quality Gate (Enterprise)
# SecureRAG Hub — Enterprise Pipeline Hardening
#
# REPLACES: scripts/ci/quality-gate.sh (the insecure version with || true)
#
# This version:
#   - REMOVES all || true bypasses
#   - REMOVES ALLOW_IMAGE_VULNERABILITIES=true
#   - REMOVES QG_REQUIRE_COSIGN=false
#   - Every check is BLOCKING
#   - Supports Checkov, Trivy, ZAP results
#
# Usage:
#   bash scripts/ci/secure-quality-gate.sh
#
# Exit codes:
#   0 = ALL CHECKS PASS
#   1 = At least one required check FAILED
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SEC_DIR="${REPO_ROOT}/security/reports"
ART_DIR="${REPO_ROOT}/artifacts/security"
COV_DIR="${REPO_ROOT}/.coverage-artifacts"
mkdir -p "${ART_DIR}"

QG_COVERAGE_MIN="${QG_COVERAGE_MIN:-85}"
OUTPUT_FILE="${ART_DIR}/secure-quality-gate-summary.md"

MD="${ART_DIR}/secure-quality-gate-summary.md"

results=()
overall="PASS"
failures=0

emit() {
  local name="$1" status="$2" details="$3"
  results+=("${name}|${status}|${details}")
  if [ "${status}" != "PASS" ]; then
    overall="FAIL"
    failures=$((failures + 1))
  fi
}

file_exists_nonempty() { [ -s "$1" ]; }

json_findings() {
  local file="$1" path="$2"
  if [ ! -s "${file}" ]; then echo "0"; return; fi
  if command -v jq >/dev/null 2>&1; then
    jq -r "${path} // 0" "${file}" 2>/dev/null || echo "0"
  else
    grep -c '"id"' "${file}" 2>/dev/null || echo "0"
  fi
}

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "═══════════════════════════════════════════════════════════════"
echo "  SECURE QUALITY GATE — ${ts}"
echo "  All checks are BLOCKING. No bypass flags allowed."
echo "═══════════════════════════════════════════════════════════════"

# ── 1. Unit Tests ───────────────────────────────────────────
junit_count=0
fail_total=0
if compgen -G "${COV_DIR}/junit-*.xml" >/dev/null 2>&1; then
  junit_count=$(ls -1 "${COV_DIR}"/junit-*.xml 2>/dev/null | wc -l | awk '{print $1}')
  fail_count=$(grep -h 'testsuite' "${COV_DIR}"/junit-*.xml 2>/dev/null | \
    sed -nE 's/.*failures="([0-9]+)".*/\1/p' | awk '{s+=$1} END {print s+0}')
  err_count=$(grep -h 'testsuite' "${COV_DIR}"/junit-*.xml 2>/dev/null | \
    sed -nE 's/.*errors="([0-9]+)".*/\1/p' | awk '{s+=$1} END {print s+0}')
  fail_total=$((fail_count + err_count))
  if [ "${fail_total}" -eq 0 ] && [ "${junit_count}" -eq 5 ]; then
    emit "unit-tests" "PASS" "${junit_count}/5 suites, 0 failures"
  elif [ "${fail_total}" -gt 0 ]; then
    emit "unit-tests" "FAIL" "${fail_total} failure(s), ${junit_count}/5 suites"
  else
    emit "unit-tests" "FAIL" "Expected 5 test suites, got ${junit_count}"
  fi
else
  emit "unit-tests" "FAIL" "No JUnit reports found"
fi

# ── 2. Coverage ─────────────────────────────────────────────
cov_pct=""
cov_file="${COV_DIR}/coverage-summary.txt"
if [ -s "${cov_file}" ]; then
  cov_pct=$(grep -E '^coverage_percent=' "${cov_file}" | cut -d= -f2 || echo "")
  if [ -n "${cov_pct}" ]; then
    if python3 -c "exit(0 if float(${cov_pct}) >= float(${QG_COVERAGE_MIN}) else 1)" 2>/dev/null; then
      emit "coverage" "PASS" "${cov_pct}% >= ${QG_COVERAGE_MIN}%"
    else
      emit "coverage" "FAIL" "${cov_pct}% < ${QG_COVERAGE_MIN}%"
    fi
  else
    emit "coverage" "FAIL" "Coverage unparseable"
  fi
else
  emit "coverage" "FAIL" "No coverage report"
fi

# ── 3. Semgrep SAST (BLOCKING) ─────────────────────────────
if file_exists_nonempty "${SEC_DIR}/semgrep.json"; then
  sg_findings=$(json_findings "${SEC_DIR}/semgrep.json" '.results | length')
  if [ "${sg_findings}" -eq 0 ]; then
    emit "semgrep" "PASS" "0 findings"
  else
    emit "semgrep" "FAIL" "${sg_findings} findings"
  fi
else
  emit "semgrep" "FAIL" "semgrep.json missing"
fi

# ── 4. Gitleaks Secrets (BLOCKING) ──────────────────────────
if file_exists_nonempty "${SEC_DIR}/gitleaks.json"; then
  leaks=$(jq 'length' "${SEC_DIR}/gitleaks.json" 2>/dev/null || echo 0)
  if [ "${leaks}" -eq 0 ]; then
    emit "gitleaks" "PASS" "0 leaks"
  else
    emit "gitleaks" "FAIL" "${leaks} leaks detected"
  fi
elif [ -e "${SEC_DIR}/gitleaks.json" ]; then
  emit "gitleaks" "PASS" "empty report"
else
  emit "gitleaks" "FAIL" "gitleaks.json missing"
fi

# ── 5. Trivy FS (BLOCKING) ─────────────────────────────────
if file_exists_nonempty "${SEC_DIR}/trivy-fs.json"; then
  trivy_critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "${SEC_DIR}/trivy-fs.json" 2>/dev/null || echo 0)
  trivy_high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "${SEC_DIR}/trivy-fs.json" 2>/dev/null || echo 0)
  if [ "${trivy_critical}" -eq 0 ]; then
    emit "trivy-fs" "PASS" "0 CRITICAL, ${trivy_high} HIGH"
  else
    emit "trivy-fs" "FAIL" "${trivy_critical} CRITICAL, ${trivy_high} HIGH"
  fi
else
  emit "trivy-fs" "FAIL" "trivy-fs.json missing"
fi

# ── 6. Trivy Image (BLOCKING — NO ALLOW_FLAG) ──────────────
if file_exists_nonempty "${SEC_DIR}/trivy-image.json"; then
  img_critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "${SEC_DIR}/trivy-image.json" 2>/dev/null || echo 0)
  if [ "${img_critical}" -eq 0 ]; then
    emit "trivy-image" "PASS" "0 CRITICAL"
  else
    emit "trivy-image" "FAIL" "${img_critical} CRITICAL vulnerabilities"
  fi
else
  # Image scan may not exist in CI (exists in CD); non-blocking if absent
  emit "trivy-image" "SKIP" "trivy-image.json not available (CD stage)"
fi

# ── 7. Dependency Audit (BLOCKING) ─────────────────────────
dep_summary="${SEC_DIR}/dependency-audit-summary.md"
if [ -s "${dep_summary}" ]; then
  if grep -q "PARTIEL" "${dep_summary}"; then
    emit "dependency-audit" "FAIL" "Vulnerabilities found"
  else
    emit "dependency-audit" "PASS" "All audits passed"
  fi
else
  emit "dependency-audit" "FAIL" "Summary missing"
fi

# ── 8. Checkov (BLOCKING — NO || true) ─────────────────────
checkov_files_found=0
for cf in "${SEC_DIR}"/checkov-*.xml; do
  [ -f "${cf}" ] && checkov_files_found=$((checkov_files_found + 1))
done

if [ "${checkov_files_found}" -gt 0 ]; then
  checkov_failures=$(grep -h 'failures=' "${SEC_DIR}"/checkov-*.xml 2>/dev/null | \
    sed -nE 's/.*failures="([0-9]+)".*/\1/p' | awk '{s+=$1} END {print s+0}')
  if [ "${checkov_failures}" -eq 0 ]; then
    emit "checkov" "PASS" "0 failures across ${checkov_files_found} reports"
  else
    emit "checkov" "FAIL" "${checkov_failures} failures"
  fi
else
  emit "checkov" "FAIL" "No Checkov reports found"
fi

# ── 9. kube-score (BLOCKING) ───────────────────────────────
ks_file="${ART_DIR}/kube-score-status.txt"
if [ -s "${ks_file}" ]; then
  ks_status=$(tr -d '\n' < "${ks_file}")
  case "${ks_status}" in
    TERMINÉ) emit "kube-score" "PASS" "All thresholds met" ;;
    PARTIEL) emit "kube-score" "FAIL" "Thresholds exceeded" ;;
    PRÊT_NON_EXÉCUTÉ) emit "kube-score" "FAIL" "Binary not available (strict mode)" ;;
    *) emit "kube-score" "FAIL" "Unknown status: ${ks_status}" ;;
  esac
else
  emit "kube-score" "FAIL" "Status file missing"
fi

# ── 10. SonarQube (BLOCKING when RUN_SONAR=true) ─────────
sonar_md="${SEC_DIR}/sonar-analysis.md"
if [ -s "${sonar_md}" ] && grep -qE 'Status:.*TERMINÉ' "${sonar_md}"; then
  emit "sonarqube" "PASS" "Quality gate passed"
elif [ -s "${sonar_md}" ]; then
  emit "sonarqube" "FAIL" "Quality gate not passed"
else
  emit "sonarqube" "SKIP" "Sonar analysis not run (RUN_SONAR=false)"
fi

# ── 11. Falco Runtime (BLOCKING) ──────────────────────────
bash "${REPO_ROOT}/scripts/ci/parse-falco.sh" && falco_status="PASS" || falco_status="FAIL"
falco_crit=$(grep "^Falco:" "${ART_DIR}/falco-summary.md" 2>/dev/null | grep -oP 'CRITICAL, \K[0-9]+' || echo "0")
if [ "${falco_status}" = "PASS" ]; then
  emit "falco" "PASS" "0 CRITICAL alerts"
else
  emit "falco" "FAIL" "${falco_crit} CRITICAL alerts — see falco-summary.md"
fi

# ── 12. Tetragon (BLOCKING) ───────────────────────────────
bash "${REPO_ROOT}/scripts/ci/parse-tetragon.sh" && tetragon_status="PASS" || tetragon_status="FAIL"
tetragon_kexec=$(grep "^Tetragon:" "${ART_DIR}/tetragon-summary.md" 2>/dev/null | grep -oP 'kubectl exec: \K[0-9]+' || echo "0")
if [ "${tetragon_status}" = "PASS" ]; then
  emit "tetragon" "PASS" "0 kubectl exec violations"
else
  emit "tetragon" "FAIL" "${tetragon_kexec} kubectl exec events detected"
fi

# ── 13. Cosign (BLOCKING — QG_REQUIRE_COSIGN=true) ────────
cs_sign="${REPO_ROOT}/artifacts/release/sign-summary.txt"
cs_verify="${REPO_ROOT}/artifacts/release/verify-summary.txt"
if [ -s "${cs_sign}" ] && grep -q 'PASS' "${cs_sign}" && \
   [ -s "${cs_verify}" ] && grep -q 'PASS' "${cs_verify}"; then
  emit "cosign" "PASS" "Sign + verify OK"
elif [ -f "${cs_sign}" ] || [ -f "${cs_verify}" ]; then
  emit "cosign" "FAIL" "Sign or verify failed"
else
  emit "cosign" "SKIP" "CD artifacts not present"
fi

# ── Render results ──────────────────────────────────────────
{
  echo "# Secure Quality Gate — ${overall}"
  echo "_Generated: ${ts}_"
  echo ""
  echo "| Check | Status | Details |"
  echo "|-------|:------:|---------|"
  for r in "${results[@]}"; do
    IFS='|' read -r name status details <<<"${r}"
    icon="❓"
    case "${status}" in
      PASS) icon="✅" ;;
      FAIL) icon="❌" ;;
      SKIP) icon="⏭️" ;;
    esac
    echo "| \`${name}\` | ${icon} ${status} | ${details} |"
  done
  echo ""
  if [ "${overall}" = "PASS" ]; then
    echo "**Verdict: PASS** — All checks green."
  else
    echo "**Verdict: FAIL** — ${failures} check(s) failed."
  fi
} > "${MD}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Verdict: ${overall} (${failures} failures)"
echo "  Report: ${MD}"
echo "═══════════════════════════════════════════════════════════════"

if [ "${overall}" = "FAIL" ]; then
  echo "FAILED CHECKS:" >&2
  for r in "${results[@]}"; do
    IFS='|' read -r name status details <<<"${r}"
    [ "${status}" = "FAIL" ] && printf '  - %-22s %s\n' "${name}" "${details}" >&2
  done
  exit 1
fi

exit 0
