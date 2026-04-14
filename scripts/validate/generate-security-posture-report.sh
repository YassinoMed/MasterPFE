#!/usr/bin/env bash

set -euo pipefail

OUT_DIR="${OUT_DIR:-artifacts/security}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/security-posture-report.md}"
NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"

mkdir -p "${OUT_DIR}"

status_file() {
  local path="$1"
  if [[ -s "${path}" ]]; then
    printf 'TERMINÉ'
  else
    printf 'PARTIEL'
  fi
}

runtime_status() {
  local command="$1"
  if eval "${command}" >/dev/null 2>&1; then
    printf 'TERMINÉ'
  else
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
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
  printf '| Gitleaks secret scan | `%s` | `security/reports/gitleaks.json`, findings=%s |\n' "$(status_file "security/reports/gitleaks.json")" "${gitleaks_findings}"
  printf '| Trivy filesystem scan | `%s` | `security/reports/trivy-fs.json`, vulnerabilities=%s |\n' "$(status_file "security/reports/trivy-fs.json")" "${trivy_vulns}"
  printf '| SBOM Syft | `%s` | `%s`, sbom_count=%s |\n' "$(status_file "${REPORT_DIR}/sbom-summary.txt")" "${REPORT_DIR}/sbom-summary.txt" "${sbom_count}"
  printf '| Cosign sign | `%s` | `%s` |\n' "$(status_file "${REPORT_DIR}/sign-summary.txt")" "${REPORT_DIR}/sign-summary.txt"
  printf '| Cosign verify | `%s` | `%s` |\n' "$(status_file "${REPORT_DIR}/verify-summary.txt")" "${REPORT_DIR}/verify-summary.txt"
  printf '| Digest promotion | `%s` | `%s` |\n' "$(status_file "${REPORT_DIR}/promotion-digests.txt")" "${REPORT_DIR}/promotion-digests.txt"
  printf '| Release attestation | `%s` | `%s` |\n' "$(status_file "${REPORT_DIR}/release-attestation.json")" "${REPORT_DIR}/release-attestation.json"
  printf '| Metrics Server runtime | `%s` | `kubectl top pods -n %s` |\n' "$(runtime_status "kubectl top pods -n ${NS}")" "${NS}"
  printf '| Kyverno runtime | `%s` | `kubectl get clusterpolicies` |\n' "$(runtime_status "kubectl get clusterpolicies")"
  printf '| Kyverno reports | `%s` | `kubectl get policyreports -A` |\n' "$(runtime_status "kubectl get policyreports -A")"
  printf '| Application workloads | `%s` | `kubectl get pods -n %s` |\n\n' "$(runtime_status "kubectl get pods -n ${NS}")" "${NS}"

  printf '## 2. Honest interpretation\n\n'
  printf -- '- `TERMINÉ` means the evidence file exists locally or the runtime command succeeds in the current environment.\n'
  printf -- '- `PARTIEL` means the control is scripted/configured but the expected evidence file is not present yet.\n'
  printf -- '- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the control needs an active Docker/kind/Kubernetes/Jenkins/Cosign/Syft/Kyverno runtime.\n\n'

  printf '## 3. Security-ready reading\n\n'
  printf 'SecureRAG Hub is security-ready for a defended demo when SAST, secret scanning, filesystem scanning, Laravel authorization tests, Kubernetes render checks, and final proof scripts pass. It becomes supply-chain-ready only after SBOM, Cosign signing, Cosign verification and digest promotion evidence are regenerated in the target environment.\n'
} > "${OUT_FILE}"

printf '[INFO] Security posture report written to %s\n' "${OUT_FILE}"
