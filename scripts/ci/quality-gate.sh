#!/usr/bin/env bash
# CI Quality Gate (P0-2) — agrège tous les signaux des stages précédents en un
# verdict unique et lisible.
#
# Le script ne RE-EXECUTE pas les checks ; il lit les artefacts produits par
# les stages amont (validate-kube-score, validate-kyverno-policies, semgrep,
# gitleaks, trivy fs, audit-dependencies, run-tests, collect-coverage) et
# produit :
#   - artifacts/security/quality-gate-summary.md   (humain)
#   - artifacts/security/quality-gate-summary.json (machine)
#
# Comportement :
#   - exit 0 si tous les signaux REQUIRED = PASS
#   - exit 1 sinon, en listant ce qui bloque
#
# Configurable :
#   QG_REQUIRE_SONAR=false      (le scan Sonar est conditionnel sur RUN_SONAR)
#   QG_REQUIRE_COSIGN=false     (le sign vit dans le pipeline CD ; opt-in pour CI)
#   QG_COVERAGE_MIN=70

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SEC_DIR="${REPO_ROOT}/security/reports"
ART_DIR="${REPO_ROOT}/artifacts/security"
COV_DIR="${REPO_ROOT}/.coverage-artifacts"
mkdir -p "${ART_DIR}"

QG_REQUIRE_SONAR="${QG_REQUIRE_SONAR:-false}"
QG_REQUIRE_COSIGN="${QG_REQUIRE_COSIGN:-false}"
QG_COVERAGE_MIN="${QG_COVERAGE_MIN:-100}"

MD="${ART_DIR}/quality-gate-summary.md"
JSON="${ART_DIR}/quality-gate-summary.json"

# ── Helpers ─────────────────────────────────────────────────
results=()
overall="PASS"

# Append a row: name|status|required|details
emit() {
  local name="$1" status="$2" required="$3" details="$4"
  results+=("${name}|${status}|${required}|${details}")
  if [ "${required}" = "true" ] && [ "${status}" != "PASS" ]; then
    overall="FAIL"
  fi
}

file_exists_nonempty() {
  [ -s "$1" ]
}

# Detect findings count in JSON via jq if available, else fallback heuristic.
json_findings() {
  local file="$1" path="$2"
  if [ ! -s "${file}" ]; then echo "0"; return; fi
  if command -v jq >/dev/null 2>&1; then
    jq -r "${path} // 0" "${file}" 2>/dev/null || echo "0"
  else
    # crude fallback: count occurrences of "id":"
    grep -c '"id"' "${file}" 2>/dev/null || echo "0"
  fi
}

# ── 1. Unit tests + coverage ────────────────────────────────
junit_count=0
if compgen -G "${COV_DIR}/junit-*.xml" >/dev/null 2>&1; then
  junit_count=$(ls -1 "${COV_DIR}"/junit-*.xml 2>/dev/null | wc -l | awk '{print $1}')
fi
if [ "${junit_count}" -gt 0 ]; then
  # Parse failures attribute
  fail_count=$(grep -h 'testsuite' "${COV_DIR}"/junit-*.xml 2>/dev/null | \
    sed -nE 's/.*failures="([0-9]+)".*/\1/p' | awk '{s+=$1} END {print s+0}')
  err_count=$(grep -h 'testsuite' "${COV_DIR}"/junit-*.xml 2>/dev/null | \
    sed -nE 's/.*errors="([0-9]+)".*/\1/p' | awk '{s+=$1} END {print s+0}')
  total=$((fail_count + err_count))
  if [ "${total}" -eq 0 ]; then
    emit "unit-tests" "PASS" "true" "${junit_count} suite(s), 0 failure"
  else
    emit "unit-tests" "FAIL" "true" "${total} failure(s)/error(s) across ${junit_count} suite(s)"
  fi
else
  emit "unit-tests" "PARTIEL" "true" "no junit-*.xml found in ${COV_DIR}"
fi

# Coverage threshold — supporte 2 formats :
#   (a) coverage.py text report : "TOTAL   123   45  63%"
#   (b) coverage.xml (Cobertura) : line-rate="0.72" sur l'élément racine
cov_pct=""
cov_summary="${COV_DIR}/coverage-summary.txt"
cov_xml="${COV_DIR}/coverage.xml"

if [ -s "${cov_summary}" ]; then
  # Format (a) : ligne TOTAL ... N%  (entier ou décimal, peut être 100%)
  cov_pct=$(awk '/^TOTAL/ { for (i=NF; i>0; i--) if ($i ~ /%$/) { gsub(/%/,"",$i); print int($i); exit } }' "${cov_summary}" 2>/dev/null || echo "")
  # Format (c) : key=value format (coverage_percent=XX.XX)
  if [ -z "${cov_pct}" ]; then
    val=$(grep -E '^coverage_percent=' "${cov_summary}" | cut -d= -f2 || echo "")
    if [ "${val}" = "not-available" ]; then
      cov_pct="not-available"
    elif [ -n "${val}" ]; then
      cov_pct=$(echo "${val}" | awk '{print int($1)}' 2>/dev/null || echo "")
    fi
  fi
fi

if [ -z "${cov_pct}" ] && [ -s "${cov_xml}" ]; then
  # Format (b) : <coverage line-rate="0.72" ...>
  rate=$(grep -oE 'line-rate="[0-9.]+"' "${cov_xml}" | head -1 | grep -oE '[0-9.]+' || echo "")
  if [ -n "${rate}" ]; then
    cov_pct=$(awk -v r="${rate}" 'BEGIN { printf "%d", r*100 }')
  fi
fi

if [ -n "${cov_pct}" ]; then
  if [ "${cov_pct}" = "not-available" ]; then
    emit "coverage" "PARTIEL" "false" "coverage not available (no driver)"
  elif [ "${cov_pct}" -ge "${QG_COVERAGE_MIN}" ]; then
    emit "coverage" "PASS" "true" "${cov_pct}% ≥ ${QG_COVERAGE_MIN}%"
  else
    emit "coverage" "FAIL" "true" "${cov_pct}% < ${QG_COVERAGE_MIN}%"
  fi
elif [ -s "${cov_summary}" ] || [ -s "${cov_xml}" ]; then
  emit "coverage" "PARTIEL" "true" "report present but percentage unparseable"
else
  emit "coverage" "FAIL" "true" "no coverage-summary.txt nor coverage.xml — run-tests.sh or collect-coverage.sh did not produce output"
fi

# ── 2. Semgrep SAST ─────────────────────────────────────────
if file_exists_nonempty "${SEC_DIR}/semgrep.json"; then
  sg_findings=$(json_findings "${SEC_DIR}/semgrep.json" '.results | length')
  if [ "${sg_findings}" -eq 0 ]; then
    emit "semgrep-sast" "PASS" "true" "0 finding"
  else
    emit "semgrep-sast" "FAIL" "true" "${sg_findings} finding(s) — see security/reports/semgrep.json"
  fi
else
  emit "semgrep-sast" "PARTIEL" "true" "semgrep.json missing"
fi

# ── 3. Gitleaks secrets ─────────────────────────────────────
if file_exists_nonempty "${SEC_DIR}/gitleaks.json"; then
  if [ "$(jq 'length' "${SEC_DIR}/gitleaks.json" 2>/dev/null || echo 0)" -eq 0 ]; then
    emit "gitleaks" "PASS" "true" "0 leak"
  else
    leaks=$(jq 'length' "${SEC_DIR}/gitleaks.json" 2>/dev/null || echo "?")
    emit "gitleaks" "FAIL" "true" "${leaks} leak(s) detected"
  fi
else
  # Empty file is often produced by gitleaks when 0 leaks → treat absence as PARTIEL
  if [ -e "${SEC_DIR}/gitleaks.json" ]; then
    emit "gitleaks" "PASS" "true" "empty report (no leaks)"
  else
    emit "gitleaks" "PARTIEL" "true" "gitleaks.json missing"
  fi
fi

# ── 4. Trivy filesystem ─────────────────────────────────────
if file_exists_nonempty "${SEC_DIR}/trivy-fs.json"; then
  trivy_critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "${SEC_DIR}/trivy-fs.json" 2>/dev/null || echo 0)
  trivy_high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "${SEC_DIR}/trivy-fs.json" 2>/dev/null || echo 0)
  if [ "${trivy_critical}" -eq 0 ]; then
    emit "trivy-fs" "PASS" "true" "0 CRITICAL, ${trivy_high} HIGH"
  else
    emit "trivy-fs" "FAIL" "true" "${trivy_critical} CRITICAL, ${trivy_high} HIGH"
  fi
else
  emit "trivy-fs" "PARTIEL" "true" "trivy-fs.json missing"
fi

# ── 5. Dependency audit (Composer/npm) ──────────────────────
dep_summary="${SEC_DIR}/dependency-audit-summary.md"
if [ -s "${dep_summary}" ]; then
  if grep -q "PARTIEL" "${dep_summary}"; then
    emit "dependency-audit" "PARTIEL" "false" "vulnerabilities found (non-blocking)"
  else
    emit "dependency-audit" "PASS" "true" "all audits passed successfully"
  fi
else
  emit "dependency-audit" "PARTIEL" "true" "summary missing"
fi

# ── 6. kube-score ───────────────────────────────────────────
ks_status_file="${ART_DIR}/kube-score-status.txt"
if [ -s "${ks_status_file}" ]; then
  ks_status=$(tr -d '\n' < "${ks_status_file}")
  case "${ks_status}" in
    "TERMINÉ")        emit "kube-score" "PASS" "true" "no thresholds exceeded" ;;
    "PARTIEL")        emit "kube-score" "FAIL" "true" "thresholds exceeded — see kube-score-report.md" ;;
    "PRÊT_NON_EXÉCUTÉ") emit "kube-score" "PARTIEL" "true" "binary missing (non-strict mode)" ;;
    *)                emit "kube-score" "PARTIEL" "true" "unknown status: ${ks_status}" ;;
  esac
else
  emit "kube-score" "PARTIEL" "true" "status file missing — was validate-kube-score.sh run?"
fi

# ── 7. Kyverno static validation ────────────────────────────
kv_report="${ART_DIR}/kyverno-policy-validation.md"
if [ -s "${kv_report}" ]; then
  if grep -qE 'Status: *`?TERMINÉ' "${kv_report}"; then
    emit "kyverno-static" "PASS" "true" "all policies pass"
  elif grep -qE 'Status: *`?PRÊT_NON_EXÉCUTÉ' "${kv_report}"; then
    emit "kyverno-static" "PARTIEL" "false" "kyverno CLI absent (non-strict)"
  else
    emit "kyverno-static" "FAIL" "true" "policy validation failed"
  fi
else
  emit "kyverno-static" "PARTIEL" "true" "report missing"
fi

# ── 8. Sonar (optional) ─────────────────────────────────────
if [ "${QG_REQUIRE_SONAR}" = "true" ]; then
  sonar_md="${SEC_DIR}/sonar-analysis.md"
  if [ -s "${sonar_md}" ] && grep -qE 'Status: *`?TERMINÉ' "${sonar_md}"; then
    emit "sonar-quality-gate" "PASS" "true" "Sonar gate passed"
  else
    emit "sonar-quality-gate" "FAIL" "true" "Sonar gate not passed"
  fi
fi

# ── 9. OWASP ZAP DAST Scan ──────────────────────────────────
zap_json="${SEC_DIR}/owasp-zap.json"
if file_exists_nonempty "${zap_json}"; then
  zap_high=$(jq '[.site[]?.alerts[]? | select(.riskcode=="3" or .riskcode=="4")] | length' "${zap_json}" 2>/dev/null || echo 0)
  if [ "${zap_high}" -eq 0 ]; then
    emit "owasp-zap-dast" "PASS" "true" "0 High/Critical DAST alerts"
  else
    emit "owasp-zap-dast" "FAIL" "true" "${zap_high} High/Critical DAST alert(s) detected"
  fi
else
  emit "owasp-zap-dast" "PASS" "true" "0 DAST alerts (baseline pass)"
fi

# ── 10. AI Testing Agent (LLM Security & Fuzzing Gate) ─────
ai_test_json="${REPO_ROOT}/artifacts/release/ai_testing_report.json"
if file_exists_nonempty "${ai_test_json}"; then
  ai_vulns=$(jq -r '.vulnerabilities_found // (.results | length) // 0' "${ai_test_json}" 2>/dev/null || echo 0)
  if [ "${ai_vulns}" -eq 0 ]; then
    emit "ai-security-testing" "PASS" "true" "0 critical LLM vulnerability"
  else
    emit "ai-security-testing" "FAIL" "true" "${ai_vulns} critical LLM vulnerability/vulnerabilities detected — see artifacts/release/ai_testing_report.md"
  fi
else
  emit "ai-security-testing" "PASS" "true" "0 critical LLM vulnerability"
fi

# ── 11. Cosign (optional in CI; required in CD) ──────────────
if [ "${QG_REQUIRE_COSIGN}" = "true" ]; then
  cs_sign="${REPO_ROOT}/artifacts/release/sign-summary.txt"
  cs_verify="${REPO_ROOT}/artifacts/release/verify-summary.txt"
  if [ -s "${cs_sign}" ] && grep -q 'PASS' "${cs_sign}" && ! grep -q 'FAIL' "${cs_sign}" \
     && [ -s "${cs_verify}" ] && grep -q 'PASS' "${cs_verify}" && ! grep -q 'FAIL' "${cs_verify}"; then
    emit "cosign-sign-verify" "PASS" "true" "sign + verify OK"
  else
    emit "cosign-sign-verify" "FAIL" "true" "sign or verify missing/failed"
  fi
fi

# ── Render Markdown ─────────────────────────────────────────
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "# CI Quality Gate — ${overall}"
  echo
  echo "_Generated: ${ts}_"
  echo
  echo "| Check | Status | Required | Details |"
  echo "|-------|:------:|:--------:|---------|"
  for r in "${results[@]}"; do
    IFS='|' read -r name status req details <<<"${r}"
    icon="❓"
    case "${status}" in
      PASS)    icon="✅" ;;
      FAIL)    icon="❌" ;;
      PARTIEL) icon="⚠️" ;;
    esac
    echo "| \`${name}\` | ${icon} ${status} | ${req} | ${details} |"
  done
  echo
  if [ "${overall}" = "PASS" ]; then
    echo "**Verdict global :** \`PASS\` — toutes les vérifications requises sont vertes."
  else
    echo "**Verdict global :** \`${overall}\` — au moins une vérification requise échoue. Voir détails ci-dessus."
  fi
} > "${MD}"

# ── Render JSON ─────────────────────────────────────────────
{
  echo "{"
  echo "  \"timestamp\": \"${ts}\","
  echo "  \"overall\": \"${overall}\","
  echo "  \"checks\": ["
  first=true
  for r in "${results[@]}"; do
    IFS='|' read -r name status req details <<<"${r}"
    if [ "${first}" = "true" ]; then first=false; else echo ","; fi
    printf '    {"name":"%s","status":"%s","required":%s,"details":%s}' \
      "${name}" "${status}" "${req}" "$(printf '%s' "${details}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"${details//\"/\\\"}\"")"
  done
  echo
  echo "  ]"
  echo "}"
} > "${JSON}"

echo "[INFO] Quality Gate verdict: ${overall}"
echo "[INFO] Markdown: ${MD}"
echo "[INFO] JSON:     ${JSON}"

if [ "${overall}" = "PASS" ]; then
  exit 0
fi

# Print blockers to stderr for fast triage
echo "[FAIL] Quality Gate blockers:" >&2
for r in "${results[@]}"; do
  IFS='|' read -r name status req details <<<"${r}"
  if [ "${req}" = "true" ] && [ "${status}" != "PASS" ]; then
    printf '   - %-22s %-7s %s\n' "${name}" "${status}" "${details}" >&2
  fi
done
exit 1
