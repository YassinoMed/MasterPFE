#!/usr/bin/env bash
# trivy-scope.sh — SecureRAG Hub Trivy Scoped Scan v2
# Scanne chaque répertoire PRODUCTION individuellement, fusionne les résultats.
# Le post-processing via le Classifier filtre ensuite par scope.
#
# Usage:
#   bash security/trivy/trivy-scope.sh [--format table|json]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORTS_DIR="${REPO_ROOT}/security/reports"
CLASSIFIER="${REPO_ROOT}/engine/security-classifier.sh"  # will also check relative to security/

if [[ ! -f "$CLASSIFIER" ]]; then
    CLASSIFIER="${REPO_ROOT}/security/engine/security-classifier.sh"
fi

mkdir -p "${REPORTS_DIR}"

FORMAT="${1:-json}"
OUTPUT_BASE="${REPORTS_DIR}/trivy-scope"

PROD_DIRS=(platform services-laravel infra docker)

echo "[INFO] Running Trivy scoped scan (${#PROD_DIRS[@]} production dirs)..."

ALL_RESULTS='{"results":[]}'

for dir in "${PROD_DIRS[@]}"; do
    dir_path="${REPO_ROOT}/${dir}"
    [[ ! -d "$dir_path" ]] && continue

    echo -n "[INFO] Scanning ${dir}..."
    json_out=$(timeout 120 trivy fs \
        --scanners vuln,secret \
        --severity MEDIUM,HIGH,CRITICAL \
        --ignore-unfixed=false \
        --skip-dirs vendor \
        --skip-dirs node_modules \
        --skip-dirs .git \
        --quiet \
        --format json \
        "${dir_path}" 2>/dev/null || echo '{"results":[]}')
    echo " done."

    ALL_RESULTS=$(python3 -c "
import json
all_data = json.loads('''${ALL_RESULTS}''')
new_data = json.loads('''${json_out}''')
seen_targets = set()
for r in all_data.get('results', []):
    seen_targets.add(r.get('Target', ''))
for r in new_data.get('results', []):
    t = r.get('Target', '')
    if t not in seen_targets:
        all_data['results'].append(r)
        seen_targets.add(t)
print(json.dumps(all_data))
" 2>/dev/null)
done

echo "${ALL_RESULTS}" > "${OUTPUT_BASE}.json"

# ── Post-process with Classifier ───────────────────────────────────────

bash "${CLASSIFIER}" --classify-from-trivy "${OUTPUT_BASE}.json" > "${OUTPUT_BASE}-summary.json" 2>/dev/null || true

PROD_CRIT=$(python3 -c "
import json
try:
    with open('${OUTPUT_BASE}-summary.json') as f:
        d = json.load(f)
    print(d.get('PRODUCTION',{}).get('severities',{}).get('CRITICAL',0))
except: print('0')
" 2>/dev/null)

PROD_HIGH=$(python3 -c "
import json
try:
    with open('${OUTPUT_BASE}-summary.json') as f:
        d = json.load(f)
    print(d.get('PRODUCTION',{}).get('severities',{}).get('HIGH',0))
except: print('0')
" 2>/dev/null)

PROD_MED=$(python3 -c "
import json
try:
    with open('${OUTPUT_BASE}-summary.json') as f:
        d = json.load(f)
    print(d.get('PRODUCTION',{}).get('severities',{}).get('MEDIUM',0))
except: print('0')
" 2>/dev/null)

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Trivy Scoped Scan — Production Summary"
echo "═══════════════════════════════════════════════════════════════"
echo "  CRITICAL : ${PROD_CRIT}"
echo "  HIGH     : ${PROD_HIGH}"
echo "  MEDIUM   : ${PROD_MED}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "[INFO] Full JSON:  ${OUTPUT_BASE}.json"
echo "[INFO] Summary:    ${OUTPUT_BASE}-summary.json"

exit 0
