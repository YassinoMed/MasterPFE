#!/usr/bin/env bash

set -euo pipefail

OUT_DIR="${OUT_DIR:-artifacts/final}"
mkdir -p "${OUT_DIR}"

status_from_file() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi
  local status
  status="$(grep -E '^- Status: `|^Statut global: `' "${file}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: `([^`]+)`.*/\1/' || true)"
  case "${status}" in
    TERMINÉ|PARTIEL|PRÊT_NON_EXÉCUTÉ|DÉPENDANT_DE_L_ENVIRONNEMENT|FAIL)
      printf '%s' "${status}"
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

  if grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' "${file}"; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  elif grep -Fq 'FAIL' "${file}"; then
    printf 'PARTIEL'
  elif grep -Fq 'PARTIEL' "${file}"; then
    printf 'PARTIEL'
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

security_file="${OUT_DIR}/security-final-status.md"
production_file="${OUT_DIR}/production-final-status.md"
release_file="${OUT_DIR}/release-final-status.md"
memoire_file="${OUT_DIR}/memoire-artifacts-to-cite.md"

security_k8s_hardening_status="$(status_from_file artifacts/security/k8s-ultra-hardening.md)"
security_runtime_status="$(status_from_file artifacts/security/runtime-security-postdeploy.md)"
security_dockerfiles_status="$(status_from_file artifacts/security/production-dockerfiles.md)"
security_secrets_status="$(status_from_file artifacts/security/secrets-management.md)"
security_kyverno_runtime_status="$(status_from_file artifacts/validation/kyverno-runtime-report.md)"
security_kyverno_blocker_status="$(status_from_file artifacts/validation/kyverno-local-registry-enforce-blocker.md)"
security_jenkins_webhook_status="$(jenkins_status_from_file artifacts/jenkins/github-webhook-validation.md)"
security_jenkins_ci_status="$(jenkins_status_from_file artifacts/jenkins/ci-push-trigger-proof.md)"
security_global_status="$(merge_status \
  "${security_k8s_hardening_status}" \
  "${security_runtime_status}" \
  "${security_dockerfiles_status}" \
  "${security_secrets_status}" \
  "${security_kyverno_runtime_status}" \
  "${security_kyverno_blocker_status}" \
  "${security_jenkins_webhook_status}" \
  "${security_jenkins_ci_status}")"

production_ha_status="$(status_from_file artifacts/security/production-ha-readiness.md)"
production_runtime_evidence_status="$(status_from_file artifacts/validation/production-runtime-evidence.md)"
production_runtime_security_status="$(status_from_file artifacts/security/runtime-security-postdeploy.md)"
production_runtime_image_status="$(status_from_file artifacts/validation/runtime-image-rollout-proof.md)"
production_hpa_status="$(status_from_file artifacts/validation/hpa-runtime-report.md)"
production_ha_chaos_status="$(status_from_file artifacts/validation/ha-chaos-lite-report.md)"
production_data_resilience_status="$(status_from_file artifacts/security/production-data-resilience.md)"
production_global_status="$(merge_status \
  "${production_ha_status}" \
  "${production_runtime_evidence_status}" \
  "${production_runtime_security_status}" \
  "${production_runtime_image_status}" \
  "${production_hpa_status}" \
  "${production_ha_chaos_status}" \
  "${production_data_resilience_status}")"

release_attestation_status="$(status_from_file artifacts/release/release-attestation.md)"
release_provenance_status="$(status_from_file artifacts/release/provenance.slsa.md)"
release_sbom_validation_status="$(status_from_file artifacts/release/sbom-cyclonedx-validation.md)"
release_supply_chain_gate_status="$(status_from_file artifacts/release/supply-chain-gate-report.md)"
release_no_rebuild_status="$(status_from_file artifacts/release/no-rebuild-deploy-summary.md)"
release_verify_status="$(status_from_file artifacts/release/verify-summary.md)"
release_global_status="$(merge_status \
  "${release_attestation_status}" \
  "${release_provenance_status}" \
  "${release_sbom_validation_status}" \
  "${release_supply_chain_gate_status}" \
  "${release_no_rebuild_status}" \
  "${release_verify_status}")"

{
  printf '# Security Final Status - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n\n' "${security_global_status}"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Kubernetes hardening static | %s | `artifacts/security/k8s-ultra-hardening.md` |\n' "${security_k8s_hardening_status}"
  printf '| Runtime security post-deploy | %s | `artifacts/security/runtime-security-postdeploy.md` |\n' "${security_runtime_status}"
  printf '| Dockerfiles production | %s | `artifacts/security/production-dockerfiles.md` |\n' "${security_dockerfiles_status}"
  printf '| Secrets management | %s | `artifacts/security/secrets-management.md` |\n' "${security_secrets_status}"
  printf '| Kyverno runtime | %s | `artifacts/validation/kyverno-runtime-report.md` |\n' "${security_kyverno_runtime_status}"
  printf '| Kyverno Enforce local registry blocker | %s | `artifacts/validation/kyverno-local-registry-enforce-blocker.md` |\n' "${security_kyverno_blocker_status}"
  printf '| Jenkins webhook proof | %s | `artifacts/jenkins/github-webhook-validation.md` |\n' "${security_jenkins_webhook_status}"
  printf '| Jenkins CI push proof | %s | `artifacts/jenkins/ci-push-trigger-proof.md` |\n' "${security_jenkins_ci_status}"
} > "${security_file}"

{
  printf '# Production Final Status - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n\n' "${production_global_status}"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Production HA static | %s | `artifacts/security/production-ha-readiness.md` |\n' "${production_ha_status}"
  printf '| Runtime evidence | %s | `artifacts/validation/production-runtime-evidence.md` |\n' "${production_runtime_evidence_status}"
  printf '| Runtime security post-deploy | %s | `artifacts/security/runtime-security-postdeploy.md` |\n' "${production_runtime_security_status}"
  printf '| Runtime image rollout | %s | `artifacts/validation/runtime-image-rollout-proof.md` |\n' "${production_runtime_image_status}"
  printf '| HPA runtime | %s | `artifacts/validation/hpa-runtime-report.md` |\n' "${production_hpa_status}"
  printf '| HA chaos lite | %s | `artifacts/validation/ha-chaos-lite-report.md` |\n' "${production_ha_chaos_status}"
  printf '| Data resilience | %s | `artifacts/security/production-data-resilience.md` |\n' "${production_data_resilience_status}"
} > "${production_file}"

{
  printf '# Release Final Status - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n\n' "${release_global_status}"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Release attestation | %s | `artifacts/release/release-attestation.json` |\n' "${release_attestation_status}"
  printf '| SLSA-style provenance | %s | `artifacts/release/provenance.slsa.md` |\n' "${release_provenance_status}"
  printf '| SBOM CycloneDX validation | %s | `artifacts/release/sbom-cyclonedx-validation.md` |\n' "${release_sbom_validation_status}"
  printf '| Supply-chain gate | %s | `artifacts/release/supply-chain-gate-report.md` |\n' "${release_supply_chain_gate_status}"
  printf '| No-rebuild deploy digest strict | %s | `artifacts/release/no-rebuild-deploy-summary.md` |\n' "${release_no_rebuild_status}"
  printf '| Cosign verify summary | %s | `artifacts/release/verify-summary.md` |\n' "${release_verify_status}"
} > "${release_file}"

{
  printf '# Artefacts DevSecOps à citer dans le mémoire\n\n'
  printf -- '- `artifacts/security/security-posture-report.md`\n'
  printf -- '- `artifacts/security/production-ha-readiness.md`\n'
  printf -- '- `artifacts/security/production-dockerfiles.md`\n'
  printf -- '- `artifacts/security/secrets-management.md`\n'
  printf -- '- `artifacts/security/runtime-security-postdeploy.md`\n'
  printf -- '- `artifacts/validation/hpa-runtime-report.md`\n'
  printf -- '- `artifacts/validation/kyverno-runtime-report.md`\n'
  printf -- '- `artifacts/validation/kyverno-local-registry-enforce-blocker.md`\n'
  printf -- '- `artifacts/validation/production-runtime-evidence.md`\n'
  printf -- '- `artifacts/validation/runtime-image-rollout-proof.md`\n'
  printf -- '- `artifacts/release/release-attestation.json`\n'
  printf -- '- `artifacts/release/no-rebuild-deploy-summary.md`\n'
  printf -- '- `artifacts/release/provenance.slsa.json`\n'
  printf -- '- `artifacts/final/security-final-status.md`\n'
  printf -- '- `artifacts/final/production-final-status.md`\n'
  printf -- '- `artifacts/final/release-final-status.md`\n'
  printf -- '- `artifacts/final/devsecops-closure-matrix.md`\n'
} > "${memoire_file}"

printf '[INFO] Final source of truth generated in %s\n' "${OUT_DIR}"
