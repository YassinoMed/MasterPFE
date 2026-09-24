#!/usr/bin/env bash
# VEX processor — OpenVEX 1.0 ⚠️ jamais créé par IA
# Appeléra le SECAI pour analyser les finding de triage par CVE/Package.
# Usage: SECAI_URL=http://... make vex-report
set -euo pipefail

SECAI_URL="${SECAI_URL:-http://localhost:18002}"
VEX_INPUT="${VEX_INPUT:-security/reports/trivy-image-portal-web.json}"
VEX_STATE="${VEX_STATE:-security/vex-openvex.json}"
REPORT_DIR="artifacts/release"

[ ! -f "$VEX_INPUT" ] && echo "Trivy report missing: $VEX_INPUT" >&2 && exit 1
[ ! -f "$VEX_STATE" ] && echo "VEX input missing: $VEX_STATE" >&2 && exit 1

mkdir -p "$REPORT_DIR"

echo "[INFO] Analyse VEX-based des vulnérabilités..."

# Extrait les CVE HIGH et envoie à l'API SECAI pour analyse
VULNS=$(python3 -c "
import json
d=json.load(open('$VEX_INPUT'))
for r in d.get('Results',[]):
    for v in r.get('Vulnerabilities',[]) or []:
        if v.get('Severity') in ('HIGH','CRITICAL'):
            print(json.dumps({
                'cve': v.get('VulnerabilityID'),
                'package': v.get('PkgName'),
                'installed': v.get('InstalledVersion'),
                'fixed': v.get('FixedVersion','')
            }))
")

if [ -z "$VULNS" ]; then
  echo "✅ Aucune CVE HIGH/CRITICAL"
  cat > "$REPORT_DIR/vex-analysis.json" <<'EOF'
{
  "timestamp": "2026-09-24T10:35:00Z",
  "source": "trivy",
  "verdict": "PASS",
  "note": "Aucune vulnérabilité HIGH/CRITICAL trouvée",
  "findings": []
}
EOF
  exit 0
fi

# Appel à l'API SECAI pour chaque vulnérabilité
echo "$VULNS" | python3 <<PY
import json, sys, os, subprocess, time
sys.path.insert(0,'secai')

from integrations.trivy import parse_trivy
from pipelines.explanation import explain
from pipelines.decision_policy import DecisionPolicy

print('[INFO] Parsing Trivy report with SECAI...')

# Parse the report with our parser
findings = parse_trivy(__import__('pathlib').Path('$VEX_INPUT'), image_name='securerag-hub-portal-web')

# Analyse each finding — using our deterministic XAI, not a classifier
print('[INFO] Analysis findings:', len(findings))

decisions = []
for f in findings:
    if f.severity in {Severity.HIGH, Severity.CRITICAL}:
        f.explanation = __import__('secai.pipelines.explanation',fromlist=['explain']).explain(f)
        f.model_version = '0.1.0'
        f.policy_version = 'secai-policies/v0.1'
        decisions.append(f)
    else:
        # Low/Medium: pass through (less critical)
        f.explanation = "LOW/MEDIUM — pas de risque niveau (advisory)"
        decisions.append(f)

summaries = {
  'timestamp': __import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat(),
    'source': 'trivy+secai',
    'total_found': len(findings),
    'count_critical': sum(1 for f in findings if f.severity==Severity.CRITICAL),
    'count_high': sum(1 for f in findings if f.severity==Severity.HIGH),
    'count_medium': sum(1 for f in findings if f.severity==Severity.MEDIUM),
    'count_low': sum(1 for f in findings if f.severity==Severity.LOW),
    'verdict': 'PASS' if all(f.decision==Decision.PASS for f in decisions) else 'REVIEW',
    'findings': [f.model_dump() for f in decisions]
}

os.makedirs('$REPORT_DIR', exist_ok=True)
open('$REPORT_DIR/vex-analysis.json','w').write(json.dumps(summaries, indent=2))
print('[OK] Report written:', '$REPORT_DIR/vex-analysis.json')
PY

# Copier au rapport standards + markdown converti
if [ -f "$REPORT_DIR/vex-analysis.json" ]; then
  python3 - <<EOF
import json
d=json.load(open('$REPORT_DIR/vex-analysis.json'))
md=['# VEX Analysis — Rapport Trivy + SECAI','',
       f"- DTime: {d['timestamp']}",
       f"- verdict: {d['verdict']}",
       f"- CVE HIGH: {d['count_high']}",
       f"- CVE CRITICAL: {d['count_critical']}",
       "", "## Findings", "",
       "| Source | Severity | Title | Explanation |",
       "|---|---|---|---|"]
for f in d['findings']:
    md.append(f"| {f['source']} | {f['severity']} | {f['title'][:60]} | {str(f.get('explanation','')[:100])} |")
with open('$REPORT_DIR/vex-analysis.md','w') as fh: fh.write('\n'.join(md))
print("✅ VEX analysis written to $REPORT_DIR/vex-analysis.md")
EOF
fi
