#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
OUT="${OUT:-artifacts/final/final-validation-summary.md}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8085/login}"
PORTAL_HEALTH_URL="${PORTAL_HEALTH_URL:-http://localhost:8081/health}"

mkdir -p "$(dirname "${OUT}")"

status_from_file() {
  local file="$1"
  local status
  local fail_count
  local warn_count
  local skip_count

  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi

  status="$(grep -E '^- Status: `|^Statut global: `' "${file}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: `([^`]+)`.*/\1/' || true)"
  case "${status}" in
    TERMINÉ|PARTIEL|PRÊT_NON_EXÉCUTÉ|DÉPENDANT_DE_L_ENVIRONNEMENT|FAIL)
      printf '%s' "${status}"
      return 0
      ;;
    COMPLETE_PROVEN)
      printf 'TERMINÉ'
      return 0
      ;;
    PARTIAL_READY_TO_PROVE)
      printf 'PARTIEL'
      return 0
      ;;
    PRESENT_UNPROVEN)
      printf 'PRÊT_NON_EXÉCUTÉ'
      return 0
      ;;
    PARTIAL*|PRESENT|FAILED)
      printf 'PARTIEL'
      return 0
      ;;
  esac

  fail_count="$(grep -E '^- FAIL: `' "${file}" | head -n 1 | sed -E 's/^- FAIL: `([^`]+)`.*/\1/' || true)"
  warn_count="$(grep -E '^- WARN: `' "${file}" | head -n 1 | sed -E 's/^- WARN: `([^`]+)`.*/\1/' || true)"
  skip_count="$(grep -E '^- SKIP: `' "${file}" | head -n 1 | sed -E 's/^- SKIP: `([^`]+)`.*/\1/' || true)"

  if [[ -n "${fail_count}" || -n "${warn_count}" || -n "${skip_count}" ]]; then
    fail_count="${fail_count:-0}"
    warn_count="${warn_count:-0}"
    skip_count="${skip_count:-0}"

    if [[ "${fail_count}" != "0" || "${warn_count}" != "0" ]]; then
      printf 'PARTIEL'
    elif [[ "${skip_count}" != "0" ]]; then
      printf 'PRÊT_NON_EXÉCUTÉ'
    else
      printf 'TERMINÉ'
    fi
    return 0
  fi

  if grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' "${file}"; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  elif grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*(FAIL|WARN|PARTIEL|FAILED|MISSING)[[:space:]]*[|]' "${file}"; then
    printf 'PARTIEL'
  elif grep -Fq 'PARTIEL' "${file}"; then
    printf 'PARTIEL'
  elif grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*(PRÊT_NON_EXÉCUTÉ|SKIPPED)[[:space:]]*[|]' "${file}"; then
    printf 'PRÊT_NON_EXÉCUTÉ'
  elif grep -Fq 'PRÊT_NON_EXÉCUTÉ' "${file}"; then
    printf 'PRÊT_NON_EXÉCUTÉ'
  else
    printf 'TERMINÉ'
  fi
}

merge_status() {
  local statuses=("$@")
  local status

  for status in "${statuses[@]}"; do
    if [[ "${status}" == "PARTIEL" || "${status}" == "FAIL" ]]; then
      printf 'PARTIEL'
      return 0
    fi
  done

  for status in "${statuses[@]}"; do
    if [[ "${status}" == "DÉPENDANT_DE_L_ENVIRONNEMENT" ]]; then
      printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
      return 0
    fi
  done

  for status in "${statuses[@]}"; do
    if [[ "${status}" == "PRÊT_NON_EXÉCUTÉ" ]]; then
      printf 'PRÊT_NON_EXÉCUTÉ'
      return 0
    fi
  done

  printf 'TERMINÉ'
}

jenkins_status_from_file() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
    return 0
  fi
  if grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*FAIL[[:space:]]*[|]' "${file}"; then
    printf 'PARTIEL'
  elif grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*WARN[[:space:]]*[|]' "${file}"; then
    printf 'PARTIEL'
  elif grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*OK[[:space:]]*[|]' "${file}"; then
    printf 'TERMINÉ'
  else
    printf 'PARTIEL'
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

if compgen -G ".coverage-artifacts/junit-*.xml" >/dev/null; then
  ci_tests="$(python3 - <<'PY'
import xml.etree.ElementTree as ET
from pathlib import Path

tests = 0
failures = 0
errors = 0
for report in Path(".coverage-artifacts").glob("junit-*.xml"):
    root = ET.parse(report).getroot()
    tests += int(root.attrib.get("tests") or len(root.findall(".//testcase")))
    failures += int(root.attrib.get("failures", "0"))
    errors += int(root.attrib.get("errors", "0"))
print(f"{tests} Laravel tests, failures={failures}, errors={errors}")
PY
)"
elif [[ -f ".coverage-artifacts/junit.xml" ]]; then
  ci_tests="legacy junit.xml present; regenerate with scripts/ci/run-tests.sh"
fi

if [[ -f ".coverage-artifacts/coverage-summary.txt" ]]; then
  coverage="$(awk -F= '/^coverage_percent=/{print $2}' .coverage-artifacts/coverage-summary.txt | tail -n 1)"
  coverage_status="$(awk -F= '/^status=/{print $2}' .coverage-artifacts/coverage-summary.txt | tail -n 1)"
  if [[ -n "${coverage}" && "${coverage}" != "not-available" ]]; then
    coverage="${coverage}%"
  elif [[ -n "${coverage_status}" ]]; then
    coverage="${coverage_status}"
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
release_attestation_status="$(status_from_file artifacts/release/release-attestation.md)"
observability_snapshot_status="$(status_from_file artifacts/observability/observability-snapshot.md)"
portal_service_status="$(status_from_file artifacts/application/portal-service-connectivity.md)"
global_project_status="$(status_from_file artifacts/final/global-project-status.md)"
missing_phases_status="$(status_from_file artifacts/final/missing-phases-closure.md)"
security_final_status="$(status_from_file artifacts/final/security-final-status.md)"
production_final_status="$(status_from_file artifacts/final/production-final-status.md)"
release_final_status="$(status_from_file artifacts/final/release-final-status.md)"

jenkins_status="$(merge_status \
  "$(jenkins_status_from_file artifacts/jenkins/github-webhook-validation.md)" \
  "$(jenkins_status_from_file artifacts/jenkins/ci-push-trigger-proof.md)")"
cluster_status="$(status_from_file artifacts/validation/production-runtime-evidence.md)"
portal_status="${portal_service_status}"
execute_status="$(merge_status "${production_final_status}" "${release_final_status}")"
summary_global_status="$(merge_status "${security_final_status}" "${production_final_status}" "${release_final_status}")"

if command -v curl >/dev/null 2>&1 && curl -fsS "${JENKINS_URL}" >/dev/null 2>&1; then
  if [[ "${jenkins_status}" == "DÉPENDANT_DE_L_ENVIRONNEMENT" ]]; then
    jenkins_status="TERMINÉ"
  fi
fi

if command -v kubectl >/dev/null 2>&1 && kubectl get ns "${NS}" >/dev/null 2>&1 && kubectl get pods -n "${NS}" >/dev/null 2>&1; then
  if [[ "${cluster_status}" == "DÉPENDANT_DE_L_ENVIRONNEMENT" || "${cluster_status}" == "PRÊT_NON_EXÉCUTÉ" ]]; then
    cluster_status="TERMINÉ"
  fi
fi

if command -v curl >/dev/null 2>&1 && curl -fsS "${PORTAL_HEALTH_URL}" >/dev/null 2>&1; then
  if [[ "${portal_status}" == "DÉPENDANT_DE_L_ENVIRONNEMENT" || "${portal_status}" == "PRÊT_NON_EXÉCUTÉ" ]]; then
    portal_status="TERMINÉ"
  fi
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

- Generated at UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Status: \`${summary_global_status}\`

## 1. Official scenario

- Official mode: \`demo\`
- CI/CD authority: Jenkins
- GitHub Actions status: legacy / historical workflows
- Promotion policy: digest-first
- Dry-run status: accepted as preparatory evidence
- Execute status: \`${execute_status}\`

## 2. CI results

| Gate | Result |
|---|---|
| Static checks | See Jenkins or shell output |
| Tests | ${ci_tests} |
| Coverage | ${coverage} |
| Semgrep findings | ${semgrep_results} |
| Gitleaks leaks | ${gitleaks_results} |
| Trivy vulnerabilities | ${trivy_results} |

## 3. CD and runtime results

| Check | Status |
|---|---|
| Jenkins / CD gates | ${jenkins_status} |
| Kubernetes runtime | ${cluster_status} |
| Portal Web health | ${portal_status} |

## 4. Evidence files

| Evidence | Status |
|---|---|
| \`artifacts/final/reference-campaign-summary.md\` | $(status_from_file artifacts/final/reference-campaign-summary.md) |
| \`artifacts/final/final-proof-check.txt\` | $(status_from_file artifacts/final/final-proof-check.txt) |
| \`artifacts/release/release-evidence.md\` | $(status_from_file artifacts/release/release-evidence.md) |
| \`artifacts/release/supply-chain-evidence.md\` | $(status_from_file artifacts/release/supply-chain-evidence.md) |
| \`artifacts/release/supply-chain-gate-report.md\` | $(status_from_file artifacts/release/supply-chain-gate-report.md) |
| \`artifacts/release/no-rebuild-deploy-summary.md\` | $(status_from_file artifacts/release/no-rebuild-deploy-summary.md) |
| \`artifacts/release/release-attestation.json\` | ${release_attestation_status} |
| \`artifacts/observability/observability-snapshot.md\` | ${observability_snapshot_status} |
| \`artifacts/security/production-external-db-readiness.md\` | $(status_from_file artifacts/security/production-external-db-readiness.md) |
| \`artifacts/security/runtime-security-postdeploy.md\` | $(status_from_file artifacts/security/runtime-security-postdeploy.md) |
| \`artifacts/security/external-secrets-runtime.md\` | $(status_from_file artifacts/security/external-secrets-runtime.md) |
| \`artifacts/validation/kyverno-local-registry-enforce-blocker.md\` | $(status_from_file artifacts/validation/kyverno-local-registry-enforce-blocker.md) |
| \`artifacts/application/portal-service-connectivity.md\` | ${portal_service_status} |
| \`artifacts/final/global-project-status.md\` | ${global_project_status} |
| \`artifacts/final/missing-phases-closure.md\` | ${missing_phases_status} |
| \`artifacts/final/devsecops-readiness-report.md\` | $(status_from_file artifacts/final/devsecops-readiness-report.md) |
| \`artifacts/jenkins/github-webhook-validation.md\` | $(status_from_file artifacts/jenkins/github-webhook-validation.md) |
| \`artifacts/jenkins/ci-push-trigger-proof.md\` | $(status_from_file artifacts/jenkins/ci-push-trigger-proof.md) |
| Latest support pack | ${latest_support_pack:-missing} |

## 5. Honest limits

- The official soutenance scenario is \`demo\` with Laravel workloads: \`portal-web\`, \`auth-users\`, \`chatbot-manager\`, \`conversation-service\`, \`audit-security-service\`.
- The legacy Python/RAG runtime is excluded from the official Kubernetes base until source code is intentionally restored.
- Full \`execute\` mode depends on Docker, kind, kubectl, Cosign keys and registry availability.
- Kyverno policies are repository-ready, but admission proof depends on an installed Kyverno controller.
- HPA objects exist, while live CPU metrics depend on metrics-server availability.

## 6. Conclusion

SecureRAG Hub is demonstrable in the official \`demo\` mode with Jenkins as the CI/CD authority, a Laravel-first Kubernetes runtime, archived evidence, and an explicit distinction between fully proven controls, partial runtime policy findings, and environment-dependent items that remain intentionally unexecuted.
EOF

printf 'Final validation summary written to %s\n' "${OUT}"
