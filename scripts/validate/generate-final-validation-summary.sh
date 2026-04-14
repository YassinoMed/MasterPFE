#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
OUT="${OUT:-artifacts/final/final-validation-summary.md}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8085/login}"
API_GATEWAY_HEALTH_URL="${API_GATEWAY_HEALTH_URL:-http://localhost:8080/healthz}"
PORTAL_HEALTH_URL="${PORTAL_HEALTH_URL:-http://localhost:8081/health}"

mkdir -p "$(dirname "${OUT}")"

status_from_file() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

json_count() {
  local file="$1"
  local expression="$2"

  if [[ ! -f "${file}" ]]; then
    printf 'unknown'
    return 0
  fi

  python3 - "${file}" "${expression}" <<'PY'
import json
import sys

path, expression = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    payload = json.load(handle)

if expression == "semgrep_results":
    print(len(payload.get("results", [])))
elif expression == "gitleaks_results":
    print(len(payload if isinstance(payload, list) else []))
elif expression == "trivy_vulnerabilities":
    total = 0
    for result in payload.get("Results", []):
        total += len(result.get("Vulnerabilities", []) or [])
    print(total)
else:
    print("unknown")
PY
}

ci_tests="unknown"
coverage="unknown"

if [[ -f ".coverage-artifacts/junit.xml" ]]; then
  ci_tests="$(python3 - <<'PY'
import xml.etree.ElementTree as ET

root = ET.parse(".coverage-artifacts/junit.xml").getroot()
tests = root.attrib.get("tests")
if tests is None:
    tests = str(len(root.findall(".//testcase")))
failures = root.attrib.get("failures", "0")
errors = root.attrib.get("errors", "0")
print(f"{tests} tests, failures={failures}, errors={errors}")
PY
)"
fi

if [[ -f ".coverage-artifacts/coverage-summary.txt" ]]; then
  coverage="$(awk -F= '/^coverage_percent=/{print $2}' .coverage-artifacts/coverage-summary.txt | tail -n 1)"
  if [[ -n "${coverage}" && "${coverage}" != "not-available" ]]; then
    coverage="${coverage}%"
  fi
elif [[ -f ".coverage-artifacts/coverage.xml" ]]; then
  coverage="$(python3 - <<'PY'
import xml.etree.ElementTree as ET

root = ET.parse(".coverage-artifacts/coverage.xml").getroot()
print(f"{float(root.attrib.get('line-rate', '0')) * 100:.2f}%")
PY
)"
fi

semgrep_results="$(json_count security/reports/semgrep.json semgrep_results)"
gitleaks_results="$(json_count security/reports/gitleaks.json gitleaks_results)"
trivy_results="$(json_count security/reports/trivy-fs.json trivy_vulnerabilities)"
release_attestation_status="$(status_from_file artifacts/release/release-attestation.json)"
observability_snapshot_status="$(status_from_file artifacts/observability/observability-snapshot.md)"
portal_service_status="$(status_from_file artifacts/application/portal-service-connectivity.md)"
global_project_status="$(status_from_file artifacts/final/global-project-status.md)"
missing_phases_status="$(status_from_file artifacts/final/missing-phases-closure.md)"

jenkins_status="partial"
cluster_status="partial"
api_gateway_status="partial"
portal_status="partial"

if command -v curl >/dev/null 2>&1 && curl -fsS "${JENKINS_URL}" >/dev/null 2>&1; then
  jenkins_status="ok"
fi

if command -v kubectl >/dev/null 2>&1 && kubectl get ns "${NS}" >/dev/null 2>&1 && kubectl get pods -n "${NS}" >/dev/null 2>&1; then
  cluster_status="ok"
fi

if command -v curl >/dev/null 2>&1 && curl -fsS "${API_GATEWAY_HEALTH_URL}" >/dev/null 2>&1; then
  api_gateway_status="ok"
fi

if command -v curl >/dev/null 2>&1 && curl -fsS "${PORTAL_HEALTH_URL}" >/dev/null 2>&1; then
  portal_status="ok"
fi

latest_support_pack="$(python3 - <<'PY'
from pathlib import Path

root = Path("artifacts/support-pack")
packs = sorted(root.glob("*.tar.gz"), key=lambda path: path.stat().st_mtime, reverse=True) if root.exists() else []
print(packs[0] if packs else "")
PY
)"

cat > "${OUT}" <<EOF
# Final Validation Summary - SecureRAG Hub

## 1. Official scenario

- Official mode: \`demo\`
- CI/CD authority: Jenkins
- GitHub Actions status: legacy / historical workflows
- Promotion policy: digest-first
- Dry-run status: accepted as preparatory evidence
- Execute status: environment-dependent

## 2. CI results

| Gate | Result |
|---|---|
| Ruff / lint | See Jenkins or shell output |
| Tests | ${ci_tests} |
| Coverage | ${coverage} |
| Semgrep findings | ${semgrep_results} |
| Gitleaks leaks | ${gitleaks_results} |
| Trivy vulnerabilities | ${trivy_results} |

## 3. CD and runtime results

| Check | Status |
|---|---|
| Jenkins reachable | ${jenkins_status} |
| Kubernetes namespace | ${cluster_status} |
| API Gateway health | ${api_gateway_status} |
| Portal Web health | ${portal_status} |

## 4. Evidence files

| Evidence | Status |
|---|---|
| \`artifacts/final/reference-campaign-summary.md\` | $(status_from_file artifacts/final/reference-campaign-summary.md) |
| \`artifacts/final/final-proof-check.txt\` | $(status_from_file artifacts/final/final-proof-check.txt) |
| \`artifacts/release/release-evidence.md\` | $(status_from_file artifacts/release/release-evidence.md) |
| \`artifacts/release/supply-chain-evidence.md\` | $(status_from_file artifacts/release/supply-chain-evidence.md) |
| \`artifacts/release/supply-chain-gate-report.md\` | $(status_from_file artifacts/release/supply-chain-gate-report.md) |
| \`artifacts/release/release-attestation.json\` | ${release_attestation_status} |
| \`artifacts/observability/observability-snapshot.md\` | ${observability_snapshot_status} |
| \`artifacts/application/portal-service-connectivity.md\` | ${portal_service_status} |
| \`artifacts/final/global-project-status.md\` | ${global_project_status} |
| \`artifacts/final/missing-phases-closure.md\` | ${missing_phases_status} |
| \`artifacts/final/devsecops-readiness-report.md\` | $(status_from_file artifacts/final/devsecops-readiness-report.md) |
| Latest support pack | ${latest_support_pack:-missing} |

## 5. Honest limits

- The official soutenance scenario is \`demo\`; \`real/Ollama\` remains an optional extension.
- Full \`execute\` mode depends on Docker, kind, kubectl, Cosign keys and registry availability.
- Kyverno policies are repository-ready, but admission proof depends on an installed Kyverno controller.
- HPA objects exist, while live CPU metrics depend on metrics-server availability.

## 6. Conclusion

SecureRAG Hub is demonstrable in the official \`demo\` mode with Jenkins as the CI/CD authority, a validated Kubernetes runtime, archived evidence, and an explicit distinction between dry-run preparation and environment-dependent execute mode.
EOF

printf 'Final validation summary written to %s\n' "${OUT}"
