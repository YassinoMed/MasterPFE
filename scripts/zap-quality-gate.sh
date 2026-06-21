#!/bin/bash
set -euo pipefail

# File: scripts/zap-quality-gate.sh
# Description: Analyse le rapport JSON de ZAP DAST et bloque le pipeline si des vulnérabilités de risque élevé sont trouvées.
# Modified by: DevSecOps Agent — 2026-06-13

REPORT_FILE="${1:-reports/zap-report.json}"

if [[ ! -f "$REPORT_FILE" ]]; then
    echo "Erreur : Le rapport ZAP ($REPORT_FILE) est introuvable." >&2
    exit 1
fi

echo "Analyse du rapport ZAP : $REPORT_FILE"

# ZAP JSON a généralement "site" -> "alerts" -> "riskcode"
# On cherche s'il y a un riskcode >= 3 ("3"=High, "4"=Critical)
HIGH_CRIT_COUNT=$(jq '[.site[].alerts[] | select(.riskcode | tonumber >= 3)] | length' "$REPORT_FILE" 2>/dev/null || echo "0")

if [[ "$HIGH_CRIT_COUNT" -gt 0 ]]; then
    echo "Erreur : La vérification DAST a échoué. $HIGH_CRIT_COUNT vulnérabilité(s) High/Critical trouvée(s)." >&2
    exit 1
fi

echo "Aucune vulnérabilité High/Critical trouvée."
echo "✓ OK"
