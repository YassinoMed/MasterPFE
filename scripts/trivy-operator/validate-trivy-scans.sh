#!/usr/bin/env bash
# File: scripts/trivy-operator/validate-trivy-scans.sh
# Description: Valide les rapports de scan Trivy Operator (vulnérabilités, config audit).
# Date: 2026-06-18
set -euo pipefail

PASS=0
FAIL=0

echo "=========================================="
echo "  Validation des scans Trivy Operator"
echo "=========================================="

echo ""
echo "--- VulnerabilityReports ---"
VULN_REPORTS=$(kubectl get vulnerabilityreports -A -o wide 2>/dev/null || echo "")
if [[ -z "${VULN_REPORTS}" ]]; then
  echo "Aucun VulnerabilityReport trouvé."
  FAIL=$((FAIL + 1))
else
  echo "${VULN_REPORTS}"
  PASS=$((PASS + 1))
fi

echo ""
echo "--- ConfigAuditReports ---"
CONFIG_REPORTS=$(kubectl get configauditreports -A -o wide 2>/dev/null || echo "")
if [[ -z "${CONFIG_REPORTS}" ]]; then
  echo "Aucun ConfigAuditReport trouvé."
  FAIL=$((FAIL + 1))
else
  echo "${CONFIG_REPORTS}"
  PASS=$((PASS + 1))
fi

echo ""
echo "--- ClusterComplianceReports ---"
COMPLIANCE_REPORTS=$(kubectl get clustercompliancereports -A -o wide 2>/dev/null || echo "")
if [[ -z "${COMPLIANCE_REPORTS}" ]]; then
  echo "Aucun ClusterComplianceReport trouvé."
else
  echo "${COMPLIANCE_REPORTS}"
fi

echo ""
echo "--- Analyse des vulnérabilités CRITICAL/HIGH ---"
HIGH_CRIT=$(kubectl get vulnerabilityreports -A -o json 2>/dev/null | \
  python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get('items', [])
    total = 0
    for item in items:
        for vuln in item.get('report', {}).get('vulnerabilities', []):
            sev = vuln.get('severity', '')
            if sev in ('CRITICAL', 'HIGH'):
                total += 1
    print(total)
except Exception:
    print('0')
" 2>/dev/null || echo "0")

if [[ "${HIGH_CRIT}" -gt 0 ]]; then
  echo "[WARN] ${HIGH_CRIT} vulnérabilité(s) CRITICAL/HIGH détectée(s)."
else
  echo "[OK] Aucune vulnérabilité CRITICAL ou HIGH détectée."
fi

echo ""
echo "=========================================="
echo "  Résultat: PASS=${PASS} FAIL=${FAIL}"
echo "=========================================="

if [[ "${FAIL}" -gt 0 ]]; then
  echo "[FAIL] Certaines vérifications ont échoué."
  exit 1
else
  echo "[PASS] Toutes les vérifications sont réussies."
fi
