#!/usr/bin/env bash
# security-classifier.sh — SecureRAG Hub Security Scoping Engine
# Classifie chaque chemin/cible en : PRODUCTION | NON_PROD | LEGACY | VENDOR
#
# Usage:
#   bash security/engine/security-classifier.sh <target_path>
#   bash security/engine/security-classifier.sh --list-all
#   bash security/engine/security-classifier.sh --classify-from-trivy <trivy-json-file>
#
# Exit codes:
#   0 = classification réussie
#   1 = erreur

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ── Scope definitions (extended regex patterns) ────────────────────────

PRODUCTION_PATTERN='^(platform/|services-laravel/|infra/k8s/|infra/terraform/|infra/ansible/|infra/helm/|docker/|security/)'
NON_PROD_PATTERN='^(tests/|scripts/|docs/|\.github/|monitoring/|artifacts/|\.coverage-artifacts/)'
LEGACY_PATTERN='^(services/|embeding/|services-laravel-archive/)'
VENDOR_PATTERN='(/vendor/|/node_modules/|/\.git/)'

# ── Function: classify a single path ───────────────────────────────────

classify() {
    local target="$1"

    # Ordre : VENDOR > LEGACY > NON_PROD > PRODUCTION

    if echo "$target" | grep -qE "$VENDOR_PATTERN"; then
        echo "VENDOR"
        return 0
    fi

    if echo "$target" | grep -qE "$LEGACY_PATTERN"; then
        echo "LEGACY"
        return 0
    fi

    if echo "$target" | grep -qE "$NON_PROD_PATTERN"; then
        echo "NON_PROD"
        return 0
    fi

    if echo "$target" | grep -qE "$PRODUCTION_PATTERN"; then
        echo "PRODUCTION"
        return 0
    fi

    echo "NON_PROD"
    return 0
}

# ── Function: classify from Trivy JSON report ──────────────────────────

classify_from_trivy() {
    local json_file="$1"

    if [[ ! -f "$json_file" ]]; then
        echo "[ERROR] Trivy report not found: $json_file" >&2
        return 1
    fi

    if ! command -v python3 &>/dev/null; then
        echo "[ERROR] python3 required" >&2
        return 1
    fi

    python3 -c "
import json, sys, re

scope_map = {
    'VENDOR': re.compile(r'(/vendor/|/node_modules/|/\.git/)'),
    'LEGACY': re.compile(r'^(services/|embeding/|services-laravel-archive/)'),
    'NON_PROD': re.compile(r'^(tests/|scripts/|docs/|\.github/|monitoring/|artifacts/|\.coverage-artifacts/)'),
    'PRODUCTION': re.compile(r'^(platform/|services-laravel/|infra/k8s/|infra/terraform/|infra/ansible/|infra/helm/|docker/|security/)'),
}

def classify(target):
    for scope_name, pattern in [('VENDOR', scope_map['VENDOR']),
                                 ('LEGACY', scope_map['LEGACY']),
                                 ('NON_PROD', scope_map['NON_PROD']),
                                 ('PRODUCTION', scope_map['PRODUCTION'])]:
        if pattern.search(target):
            return scope_name
    return 'NON_PROD'

try:
    with open('$json_file') as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError) as e:
    print(json.dumps({'error': str(e)}))
    sys.exit(1)

results = data.get('results', [])
classified = {
    'PRODUCTION': {'targets': [], 'total_vulns': 0, 'total_secrets': 0, 'severities': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}, 'findings': []},
    'NON_PROD': {'targets': [], 'total_vulns': 0, 'total_secrets': 0, 'severities': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}, 'findings': []},
    'LEGACY': {'targets': [], 'total_vulns': 0, 'total_secrets': 0, 'severities': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}, 'findings': []},
    'VENDOR': {'targets': [], 'total_vulns': 0, 'total_secrets': 0, 'severities': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}, 'findings': []},
}

for r in results:
    target = r.get('Target', 'unknown')
    scope = classify(target)
    classified[scope]['targets'].append(target)
    for v in r.get('Vulnerabilities', []):
        sev = v.get('Severity', 'UNKNOWN')
        classified[scope]['total_vulns'] += 1
        if sev in classified[scope]['severities']:
            classified[scope]['severities'][sev] += 1
        classified[scope]['findings'].append({
            'id': v.get('VulnerabilityID'),
            'severity': sev,
            'pkg': v.get('PkgName'),
            'title': (v.get('Title') or '')[:80],
            'target': target,
        })
    for s in r.get('Secrets', []):
        sev = s.get('Severity', 'UNKNOWN')
        classified[scope]['total_secrets'] += 1
        if sev in classified[scope]['severities']:
            classified[scope]['severities'][sev] += 1
        classified[scope]['findings'].append({
            'id': s.get('RuleID'),
            'severity': sev,
            'pkg': 'secret',
            'title': (s.get('Title') or '')[:80],
            'target': target,
        })

print(json.dumps(classified, indent=2))
" 2>&1
}

# ── Function: list all paths in repo with scope classification ─────────

list_all() {
    echo "[INFO] Scanning repository and classifying all paths..."
    echo "TARGET|SCOPE"
    echo "-----|-----"

    find "${REPO_ROOT}" -maxdepth 3 -type d \
        -not -path '*/vendor/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' \
        -not -path '*/.coverage-artifacts/*' \
        -not -path '*/security/reports/*' \
        2>/dev/null | sort | while read -r dir; do
        rel="${dir#${REPO_ROOT}/}"
        if [[ -n "$rel" ]]; then
            scope=$(classify "${rel}/")
            echo "${rel}|${scope}"
        fi
    done
}

# ── Main ───────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --list-all)
            list_all
            ;;
        --classify-from-trivy)
            if [[ -z "${2:-}" ]]; then
                echo "[ERROR] Usage: $0 --classify-from-trivy <trivy-json-file>" >&2
                exit 1
            fi
            classify_from_trivy "$2"
            ;;
        --help|-h)
            echo "Usage: $0 [OPTION] [TARGET]"
            echo ""
            echo "Options:"
            echo "  <target_path>             Classify a single path"
            echo "  --list-all                List all paths with classification"
            echo "  --classify-from-trivy <f> Classify all targets in a Trivy JSON report"
            echo "  --help                    Show this help"
            ;;
        *)
            if [[ -n "${1:-}" ]]; then
                classify "$1"
            else
                echo "[ERROR] No target specified. Use --help for usage." >&2
                exit 1
            fi
            ;;
    esac
}

main "$@"
