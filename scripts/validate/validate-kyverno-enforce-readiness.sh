#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/kyverno-enforce-readiness.md}"
KYVERNO_RUNTIME_REPORT="${KYVERNO_RUNTIME_REPORT:-${REPORT_DIR}/kyverno-runtime-report.md}"
ATTESTATION_FILE="${ATTESTATION_FILE:-artifacts/release/release-attestation.json}"

mkdir -p "${REPORT_DIR}"

status="PRÊT_NON_EXÉCUTÉ"
reason="Kyverno runtime report or complete supply-chain attestation is missing."

if [[ -x scripts/validate/validate-kyverno-runtime.sh ]]; then
  bash scripts/validate/validate-kyverno-runtime.sh >/dev/null || true
fi

if [[ -s "${KYVERNO_RUNTIME_REPORT}" ]] && grep -Fq '| Kyverno Enforce readiness | TERMINÉ |' "${KYVERNO_RUNTIME_REPORT}"; then
  status="TERMINÉ"
  reason="Kyverno runtime report says Enforce readiness is TERMINÉ."
elif [[ -s "${KYVERNO_RUNTIME_REPORT}" ]] && grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' "${KYVERNO_RUNTIME_REPORT}"; then
  status="DÉPENDANT_DE_L_ENVIRONNEMENT"
  reason="Cluster, Kyverno CRDs/controllers or PolicyReports are not reachable in this environment."
fi

{
  printf '# Kyverno Enforce Readiness - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "${status}"
  printf -- '- Kyverno runtime report: `%s`\n' "${KYVERNO_RUNTIME_REPORT}"
  printf -- '- Release attestation: `%s`\n\n' "${ATTESTATION_FILE}"
  printf '| Gate | Expected |\n'
  printf '|---|---|\n'
  printf '| Kyverno Audit installed | CRDs and controllers Ready |\n'
  printf '| SecureRAG policies | All ClusterPolicies present in Audit mode |\n'
  printf '| PolicyReports | Present and without fail/error for blocking controls |\n'
  printf '| Supply chain | `release-attestation.json` is `COMPLETE_PROVEN` |\n'
  printf '| Deployment | Images deployed by promoted immutable digest |\n\n'
  printf '## Decision\n\n%s\n\n' "${reason}"
  printf '## Next action\n\n'
  if [[ "${status}" == "TERMINÉ" ]]; then
    printf 'Enforce can be trialed progressively, starting with Pod Security/resource policies before Cosign image verification.\n'
  else
    printf 'Keep Kyverno in Audit. Do not apply `make kyverno-enforce` until this report is `TERMINÉ`.\n'
  fi
} > "${REPORT_FILE}"

printf '[INFO] Kyverno Enforce readiness written to %s\n' "${REPORT_FILE}"
