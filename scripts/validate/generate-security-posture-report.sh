#!/usr/bin/env bash

set -euo pipefail

OUT_DIR="${OUT_DIR:-artifacts/security}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/security-posture-report.md}"
NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"

DEFAULT_SERVICES=(
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
  portal-web
)

if [[ -n "${SERVICES:-}" ]]; then
  # shellcheck disable=SC2206
  SERVICES_ARRAY=(${SERVICES//,/ })
else
  SERVICES_ARRAY=("${DEFAULT_SERVICES[@]}")
fi

EXPECTED_COUNT="${EXPECTED_SERVICE_COUNT:-${#SERVICES_ARRAY[@]}}"

mkdir -p "${OUT_DIR}"

status_file() {
  local path="$1"
  if [[ -s "${path}" ]]; then
    printf 'TERMINÉ'
  else
    printf 'PARTIEL'
  fi
}

status_count() {
  local path="$1"
  local status="$2"
  local count

  count="$(grep -Ec "^[[:space:]]*${status}[[:space:]]*[|]" "${path}" 2>/dev/null || true)"
  printf '%s' "${count:-0}"
}

summary_state() {
  local path="$1"

  if [[ ! -s "${path}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  local pass_count fail_count skip_count
  pass_count="$(status_count "${path}" "PASS")"
  fail_count="$(status_count "${path}" "FAIL")"
  skip_count="$(status_count "${path}" "SKIP")"

  if [[ "${pass_count}" == "${EXPECTED_COUNT}" && "${fail_count}" == "0" && "${skip_count}" == "0" ]]; then
    printf 'TERMINÉ'
  else
    printf 'PARTIEL'
  fi
}

digest_state() {
  local path="$1"

  if [[ ! -s "${path}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  local record_count invalid_count
  record_count="$(grep -Ev '^[[:space:]]*(#|$)' "${path}" | wc -l | tr -d ' ')"
  invalid_count="$(grep -Ev '^[[:space:]]*(#|$)' "${path}" | awk -F'|' '$4 !~ /^sha256:[0-9a-f]{64}$/ {bad++} END {print bad+0}')"

  if [[ "${record_count}" == "${EXPECTED_COUNT}" && "${invalid_count}" == "0" ]]; then
    printf 'TERMINÉ'
  else
    printf 'PARTIEL'
  fi
}

attestation_state() {
  local path="$1"

  if [[ ! -s "${path}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  python3 - "${path}" <<'PY' 2>/dev/null || { printf 'PARTIEL'; exit 0; }
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

print("TERMINÉ" if payload.get("status") == "COMPLETE_PROVEN" else "PARTIEL")
PY
}

runtime_status() {
  local command="$1"
  if eval "${command}" >/dev/null 2>&1; then
    printf 'TERMINÉ'
  else
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  fi
}

markdown_global_status() {
  local path="$1"
  local expected="$2"

  if [[ -s "${path}" ]] && grep -Fq "${expected}" "${path}"; then
    printf 'TERMINÉ'
  else
    printf 'PARTIEL'
  fi
}

declared_status() {
  local path="$1"

  if [[ ! -s "${path}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  local declared
  declared="$(grep -E 'Status: `|Statut global: ' "${path}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: ([^.`]+).*/\1/' || true)"
  if [[ -n "${declared}" ]]; then
    printf '%s' "${declared}"
  else
    status_file "${path}"
  fi
}

table_worst_status() {
  local path="$1"

  if [[ ! -s "${path}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  if grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' "${path}"; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  elif grep -Eq 'FAIL|PARTIEL' "${path}"; then
    printf 'PARTIEL'
  elif grep -Fq 'TERMINÉ' "${path}"; then
    printf 'TERMINÉ'
  else
    printf 'PARTIEL'
  fi
}

count_json_results() {
  local path="$1"
  local expression="$2"

  if [[ ! -s "${path}" ]]; then
    printf 'n/a'
    return 0
  fi

  python3 - "$path" "$expression" <<'PY' 2>/dev/null || printf 'n/a'
import json
import sys

path, expression = sys.argv[1:3]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

if expression == "semgrep":
    print(len(data.get("results", [])))
elif expression == "gitleaks":
    print(len(data) if isinstance(data, list) else 0)
elif expression == "trivy-vulns":
    total = 0
    for result in data.get("Results", []):
        total += len(result.get("Vulnerabilities") or [])
    print(total)
else:
    print("n/a")
PY
}

sbom_count=0
if [[ -d "${SBOM_DIR}" ]]; then
  sbom_count="$(find "${SBOM_DIR}" -type f -name '*-sbom.cdx.json' 2>/dev/null | wc -l | tr -d ' ')"
fi

semgrep_findings="$(count_json_results "security/reports/semgrep.json" "semgrep")"
gitleaks_findings="$(count_json_results "security/reports/gitleaks.json" "gitleaks")"
trivy_vulns="$(count_json_results "security/reports/trivy-fs.json" "trivy-vulns")"

{
  printf '# Security Posture Report — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Git commit: `%s`\n' "$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
  printf -- '- Kubernetes namespace: `%s`\n\n' "${NS}"

  printf '## 1. Security controls status\n\n'
  printf '| Control | State | Evidence |\n'
  printf '|---|---|---|\n'
  printf '| Semgrep SAST | `%s` | `security/reports/semgrep.json`, findings=%s |\n' "$(status_file "security/reports/semgrep.json")" "${semgrep_findings}"
  printf '| Sonar CPD scope | `%s` | `artifacts/security/sonar-cpd-scope.md` |\n' "$(markdown_global_status "artifacts/security/sonar-cpd-scope.md" "Statut global: TERMINÉ")"
  printf '| Sonar Quality Gate | `%s` | `security/reports/sonar-analysis.md` |\n' "$(declared_status "security/reports/sonar-analysis.md")"
  printf '| Gitleaks secret scan | `%s` | `security/reports/gitleaks.json`, findings=%s |\n' "$(status_file "security/reports/gitleaks.json")" "${gitleaks_findings}"
  printf '| Trivy filesystem scan | `%s` | `security/reports/trivy-fs.json`, vulnerabilities=%s |\n' "$(status_file "security/reports/trivy-fs.json")" "${trivy_vulns}"
  printf '| Trivy image scan | `%s` | `%s` |\n' "$(summary_state "${REPORT_DIR}/image-scan-summary.txt")" "${REPORT_DIR}/image-scan-summary.txt"
  printf '| SBOM Syft | `%s` | `%s`, sbom_count=%s, expected=%s |\n' "$(summary_state "${REPORT_DIR}/sbom-summary.txt")" "${REPORT_DIR}/sbom-summary.txt" "${sbom_count}" "${EXPECTED_COUNT}"
  printf '| SBOM Cosign attestation | `%s` | `%s` |\n' "$(summary_state "${REPORT_DIR}/attest-summary.txt")" "${REPORT_DIR}/attest-summary.txt"
  printf '| Cosign sign | `%s` | `%s` |\n' "$(summary_state "${REPORT_DIR}/sign-summary.txt")" "${REPORT_DIR}/sign-summary.txt"
  printf '| Cosign verify | `%s` | `%s` |\n' "$(summary_state "${REPORT_DIR}/verify-summary.txt")" "${REPORT_DIR}/verify-summary.txt"
  printf '| Digest promotion | `%s` | `%s` |\n' "$(digest_state "${REPORT_DIR}/promotion-digests.txt")" "${REPORT_DIR}/promotion-digests.txt"
  printf '| Release attestation | `%s` | `%s` |\n' "$(attestation_state "${REPORT_DIR}/release-attestation.json")" "${REPORT_DIR}/release-attestation.json"
  printf '| Kubernetes ultra hardening static | `%s` | `artifacts/security/k8s-ultra-hardening.md` |\n' "$(markdown_global_status "artifacts/security/k8s-ultra-hardening.md" "Statut global: TERMINÉ")"
  printf '| Kubernetes production HA static | `%s` | `artifacts/security/production-ha-readiness.md` |\n' "$(markdown_global_status "artifacts/security/production-ha-readiness.md" "Statut global: TERMINÉ")"
  printf '| Production runtime evidence | `%s` | `artifacts/validation/production-runtime-evidence.md` |\n' "$(table_worst_status "artifacts/validation/production-runtime-evidence.md")"
  printf '| Kyverno policy CLI validation | `%s` | `artifacts/security/kyverno-policy-validation.md` |\n' "$(declared_status "artifacts/security/kyverno-policy-validation.md")"
  printf '| Metrics Server runtime | `%s` | `kubectl top pods -n %s` |\n' "$(runtime_status "kubectl top pods -n ${NS}")" "${NS}"
  printf '| Kyverno runtime | `%s` | `kubectl get clusterpolicies` |\n' "$(runtime_status "kubectl get clusterpolicies")"
  printf '| Kyverno reports | `%s` | `kubectl get policyreports -A` |\n' "$(runtime_status "kubectl get policyreports -A")"
  printf '| Application workloads | `%s` | `kubectl get pods -n %s` |\n\n' "$(runtime_status "kubectl get pods -n ${NS}")" "${NS}"

  printf '## 2. Honest interpretation\n\n'
  printf -- '- `TERMINÉ` means all expected evidence rows are proven, or the runtime command succeeds in the current environment.\n'
  printf -- '- `PARTIEL` means the control is scripted/configured but the expected evidence is missing, incomplete, failed, skipped or partial.\n'
  printf -- '- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the control needs an active Docker/kind/Kubernetes/Jenkins/Cosign/Syft/Kyverno runtime.\n\n'

  printf '## 3. Security-ready reading\n\n'
  printf 'SecureRAG Hub is security-ready for a defended Laravel demo when SAST, Sonar scope validation, secret scanning, filesystem scanning, Laravel authorization tests, Kubernetes render checks, and final proof scripts pass. It becomes supply-chain-ready only after Trivy image scanning, SBOM generation, SBOM attestation, Cosign signing, Cosign verification and digest promotion evidence are regenerated in the target environment for the official service set.\n'
} > "${OUT_FILE}"

printf '[INFO] Security posture report written to %s\n' "${OUT_FILE}"
