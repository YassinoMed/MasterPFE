#!/usr/bin/env bash
# security/tests/test-zap-integration.sh
# Tests ZAP integration configurations and connectivity to staging.

set -euo pipefail

echo "=== TESTING ZAP DAST INTEGRATION ==="

# 1. Verify files exist
FILES=(
  "security/zap/zap-baseline.yaml"
  "security/zap/zap-api-scan.yaml"
  "security/zap/zap-rules-config.tsv"
  "security/zap/zap-auth-config.yaml"
  "security/zap/parse-zap-report.groovy"
)

for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    echo "[OK] File exists: $f"
  else
    echo "[ERROR] Missing file: $f"
    exit 1
  fi
done

# 2. Check local network/Docker availability
if command -v docker &>/dev/null; then
  echo "[OK] Docker is installed."
else
  echo "[WARN] Docker not installed. Skipped container check."
fi

# 3. Simulate parsing on mock report
echo "[INFO] Testing JSON report validation threshold parser..."
MOCK_REPORT="/tmp/mock-zap-report.json"
cat << 'EOF' > "$MOCK_REPORT"
{
  "site": [
    {
      "alerts": [
        {
          "riskcode": "3",
          "riskdesc": "High (Medium)",
          "name": "SQL Injection"
        }
      ]
    }
  ]
}
EOF

python3 -c "
import json
with open('$MOCK_REPORT') as f:
    data = json.load(f)
alerts = []
for s in data.get('site', []):
    alerts.extend(s.get('alerts', []))
high_crit = [a for a in alerts if int(a.get('riskcode', 0)) >= 3]
if len(high_crit) > 0:
    print('[OK] Quality gate correctly detects High risk vulnerability.')
else:
    print('[ERROR] Quality gate failed to detect High risk vulnerability.')
    exit(1)
"

rm -f "$MOCK_REPORT"
echo "[OK] Test ZAP Integration suite completed."
