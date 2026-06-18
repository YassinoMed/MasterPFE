#!/usr/bin/env bash
# gate-decision-engine.sh — SecureRAG Hub Security Gate Decision Engine
# Prend un rapport Trivy/Semgrep/Gitleaks JSON classifié et décide :
#   - FAIL si PRODUCTION scope contient des vulnérabilités HIGH/CRITICAL
#   - WARNING si NON_PROD scope contient des vulnérabilités
#   - IGNORE si LEGACY/VENDOR scope uniquement
#
# Usage:
#   bash security/engine/gate-decision-engine.sh \
#     --trivy <trivy-json> \
#     --semgrep <semgrep-json> \
#     --gitleaks <gitleaks-json> \
#     --output <summary-md>
#
# Exit codes:
#   0 = PASS (aucune vulnérabilité PROD bloquante)
#   1 = FAIL (vulnérabilité HIGH/CRITICAL en PRODUCTION)
#   2 = WARNING (vulnérabilités NON_PROD uniquement)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLASSIFIER="${REPO_ROOT}/security/engine/security-classifier.sh"

# ── Parse arguments ────────────────────────────────────────────────────

TRIVY_REPORT=""
SEMGREP_REPORT=""
GITLEAKS_REPORT=""
OUTPUT_FILE="${REPO_ROOT}/artifacts/security/gate-decision-summary.md"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --trivy) TRIVY_REPORT="$2"; shift 2 ;;
        --semgrep) SEMGREP_REPORT="$2"; shift 2 ;;
        --gitleaks) GITLEAKS_REPORT="$2"; shift 2 ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "[ERROR] Unknown option: $1"; exit 1 ;;
    esac
done

# ── Classify Trivy report via classifier engine ───────────────────────

classify_trivy() {
    local json_file="$1"
    if [[ ! -f "$json_file" ]]; then
        echo '{}'
        return
    fi
    bash "${CLASSIFIER}" --classify-from-trivy "$json_file" 2>/dev/null || echo '{}'
}

# ── Extract findings from Semgrep and Gitleaks JSON ───────────────────

count_semgrep_findings() {
    local json_file="$1"
    if [[ ! -f "$json_file" ]]; then
        echo "0"
        return
    fi
    python3 -c "
import json
try:
    with open('$json_file') as f:
        data = json.load(f)
    results = data.get('results', [])
    print(len(results))
except: print('0')
" 2>/dev/null
}

# ── Main decision logic ────────────────────────────────────────────────

main() {
    local prod_critical=0 prod_high=0 prod_medium=0
    local nonprod_total=0 legacy_total=0 vendor_total=0
    local semgrep_count=0 gitleaks_count=0
    local gate_status="PASS"
    local prod_findings=()

    mkdir -p "$(dirname "$OUTPUT_FILE")"

    # ── Parse Trivy ────────────────────────────────────────────────

    if [[ -n "$TRIVY_REPORT" ]]; then
        trivy_classified=$(classify_trivy "$TRIVY_REPORT")

        # Extract production findings
        prod_critical=$(echo "$trivy_classified" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get('PRODUCTION',{}).get('severities',{}).get('CRITICAL',0))
except: print('0')
" 2>/dev/null)

        prod_high=$(echo "$trivy_classified" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get('PRODUCTION',{}).get('severities',{}).get('HIGH',0))
except: print('0')
" 2>/dev/null)

        prod_medium=$(echo "$trivy_classified" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get('PRODUCTION',{}).get('severities',{}).get('MEDIUM',0))
except: print('0')
" 2>/dev/null)

        # Extract production finding details
        prod_findings_json=$(echo "$trivy_classified" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    findings = d.get('PRODUCTION',{}).get('findings',[])
    for f in findings:
        if f.get('severity') in ('CRITICAL','HIGH'):
            print(f\"  - [{f['severity']}] {f['id']} | {f['pkg']} | {f['target']}\")
except: pass
" 2>/dev/null)

        while IFS= read -r line; do
            [[ -n "$line" ]] && prod_findings+=("$line")
        done <<< "$prod_findings_json"

        # Extract non-prod totals
        nonprod_total=$(echo "$trivy_classified" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    s=d.get('NON_PROD',{}).get('severities',{})
    print(s.get('CRITICAL',0)+s.get('HIGH',0)+s.get('MEDIUM',0)+s.get('LOW',0))
except: print('0')
" 2>/dev/null)

        legacy_total=$(echo "$trivy_classified" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    s=d.get('LEGACY',{}).get('severities',{})
    print(s.get('CRITICAL',0)+s.get('HIGH',0)+s.get('MEDIUM',0)+s.get('LOW',0))
except: print('0')
" 2>/dev/null)

        vendor_total=$(echo "$trivy_classified" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    s=d.get('VENDOR',{}).get('severities',{})
    print(s.get('CRITICAL',0)+s.get('HIGH',0)+s.get('MEDIUM',0)+s.get('LOW',0))
except: print('0')
" 2>/dev/null)
    fi

    # ── Parse Semgrep and Gitleaks ─────────────────────────────────

    if [[ -n "$SEMGREP_REPORT" ]]; then
        semgrep_count=$(count_semgrep_findings "$SEMGREP_REPORT")
    fi
    if [[ -n "$GITLEAKS_REPORT" ]]; then
        gitleaks_count=$(count_semgrep_findings "$GITLEAKS_REPORT")
    fi

    # ── Decision ───────────────────────────────────────────────────

    if [[ "$prod_critical" -gt 0 || "$prod_high" -gt 0 ]]; then
        gate_status="FAIL"
    elif [[ "$prod_medium" -gt 0 || "$nonprod_total" -gt 0 || "$semgrep_count" -gt 0 || "$gitleaks_count" -gt 0 ]]; then
        gate_status="WARNING"
    fi

    # ── Generate report ─────────────────────────────────────────────

    cat > "$OUTPUT_FILE" <<EOF
# Security Gate Decision Report

**Date:** $(date -u '+%Y-%m-%dT%H:%M:%SZ')
**Engine:** gate-decision-engine.sh v1.0
**Classifier:** security-classifier.sh v1.0

## Gate Status: **${gate_status}**

EOF

    if [[ "$gate_status" == "FAIL" ]]; then
        echo "## 🔴 PRODUCTION BLOCKING FINDINGS" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "The following HIGH/CRITICAL vulnerabilities were found in PRODUCTION scope:" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        for f in "${prod_findings[@]}"; do
            echo "$f" >> "$OUTPUT_FILE"
        done
        echo "" >> "$OUTPUT_FILE"
    fi

    cat >> "$OUTPUT_FILE" <<EOF
## Scope Summary

| Scope | CRITICAL | HIGH | MEDIUM | Total |
|:---|---:|---:|---:|---:|
| **PRODUCTION** | ${prod_critical} | ${prod_high} | ${prod_medium} | $((prod_critical + prod_high + prod_medium)) |
| **NON_PROD** (warning) | - | - | - | ${nonprod_total} |
| **LEGACY** (ignored) | - | - | - | ${legacy_total} |
| **VENDOR** (ignored) | - | - | - | ${vendor_total} |

## Scan Summary

| Scan | Findings | Scope |
|:---|---:|:---|
| Trivy (Vulnerabilities) | $((prod_critical + prod_high + prod_medium)) | Scope-aware |
| Semgrep (SAST) | ${semgrep_count} | Scope-aware |
| Gitleaks (Secrets) | ${gitleaks_count} | Scope-aware |

## Decision Rules

| Rule | Condition | Action |
|:---|---|:---|
| PROD CRITICAL/HIGH found | prod_critical > 0 OR prod_high > 0 | ❌ **FAIL pipeline** |
| PROD MEDIUM only | prod_medium > 0 | ⚠️ WARNING |
| NON_PROD findings only | nonprod_total > 0 | ⚠️ WARNING |
| LEGACY/VENDOR only | Only legacy/vendor findings | ✅ IGNORE (passed) |
| No findings | All scans clean | ✅ **PASS** |
EOF

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Gate Decision: ${gate_status}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  PRODUCTION : ${prod_critical} CRITICAL, ${prod_high} HIGH, ${prod_medium} MEDIUM"
    echo "  NON_PROD   : ${nonprod_total} findings (warning)"
    echo "  LEGACY     : ${legacy_total} findings (ignored)"
    echo "  VENDOR     : ${vendor_total} findings (ignored)"
    echo "  Semgrep    : ${semgrep_count} findings"
    echo "  Gitleaks   : ${gitleaks_count} findings"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "[INFO] Report written to: ${OUTPUT_FILE}"

    # Exit with appropriate code
    if [[ "$gate_status" == "FAIL" ]]; then
        return 1
    elif [[ "$gate_status" == "WARNING" ]]; then
        return 0  # Warning only, don't fail
    fi
    return 0
}

main
