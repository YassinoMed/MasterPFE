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
    PARTIAL_READY_TO_PROVE|PRESENT_UNPROVEN)
      printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
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

{
  printf '# Security Final Status - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Kubernetes hardening static | %s | `artifacts/security/k8s-ultra-hardening.md` |\n' "$(status_from_file artifacts/security/k8s-ultra-hardening.md)"
  printf '| Runtime security post-deploy | %s | `artifacts/security/runtime-security-postdeploy.md` |\n' "$(status_from_file artifacts/security/runtime-security-postdeploy.md)"
  printf '| Dockerfiles production | %s | `artifacts/security/production-dockerfiles.md` |\n' "$(status_from_file artifacts/security/production-dockerfiles.md)"
  printf '| Secrets management | %s | `artifacts/security/secrets-management.md` |\n' "$(status_from_file artifacts/security/secrets-management.md)"
  printf '| Kyverno runtime | %s | `artifacts/validation/kyverno-runtime-report.md` |\n' "$(status_from_file artifacts/validation/kyverno-runtime-report.md)"
  printf '| Kyverno Enforce local registry blocker | %s | `artifacts/validation/kyverno-local-registry-enforce-blocker.md` |\n' "$(status_from_file artifacts/validation/kyverno-local-registry-enforce-blocker.md)"
  printf '| Jenkins webhook proof | %s | `artifacts/jenkins/github-webhook-validation.md` |\n' "$(jenkins_status_from_file artifacts/jenkins/github-webhook-validation.md)"
  printf '| Jenkins CI push proof | %s | `artifacts/jenkins/ci-push-trigger-proof.md` |\n' "$(jenkins_status_from_file artifacts/jenkins/ci-push-trigger-proof.md)"
} > "${security_file}"

{
  printf '# Production Final Status - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Production HA static | %s | `artifacts/security/production-ha-readiness.md` |\n' "$(status_from_file artifacts/security/production-ha-readiness.md)"
  printf '| Runtime evidence | %s | `artifacts/validation/production-runtime-evidence.md` |\n' "$(status_from_file artifacts/validation/production-runtime-evidence.md)"
  printf '| Runtime security post-deploy | %s | `artifacts/security/runtime-security-postdeploy.md` |\n' "$(status_from_file artifacts/security/runtime-security-postdeploy.md)"
  printf '| Runtime image rollout | %s | `artifacts/validation/runtime-image-rollout-proof.md` |\n' "$(status_from_file artifacts/validation/runtime-image-rollout-proof.md)"
  printf '| HPA runtime | %s | `artifacts/validation/hpa-runtime-report.md` |\n' "$(status_from_file artifacts/validation/hpa-runtime-report.md)"
  printf '| HA chaos lite | %s | `artifacts/validation/ha-chaos-lite-report.md` |\n' "$(status_from_file artifacts/validation/ha-chaos-lite-report.md)"
  printf '| Data resilience | %s | `artifacts/security/production-data-resilience.md` |\n' "$(status_from_file artifacts/security/production-data-resilience.md)"
} > "${production_file}"

{
  printf '# Release Final Status - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Release attestation | %s | `artifacts/release/release-attestation.json` |\n' "$(status_from_file artifacts/release/release-attestation.md)"
  printf '| SLSA-style provenance | %s | `artifacts/release/provenance.slsa.md` |\n' "$(status_from_file artifacts/release/provenance.slsa.md)"
  printf '| SBOM CycloneDX validation | %s | `artifacts/release/sbom-cyclonedx-validation.md` |\n' "$(status_from_file artifacts/release/sbom-cyclonedx-validation.md)"
  printf '| Supply-chain gate | %s | `artifacts/release/supply-chain-gate-report.md` |\n' "$(status_from_file artifacts/release/supply-chain-gate-report.md)"
  printf '| No-rebuild deploy digest strict | %s | `artifacts/release/no-rebuild-deploy-summary.md` |\n' "$(status_from_file artifacts/release/no-rebuild-deploy-summary.md)"
  printf '| Cosign verify summary | %s | `artifacts/release/verify-summary.md` |\n' "$(status_from_file artifacts/release/verify-summary.md)"
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
} > "${memoire_file}"

printf '[INFO] Final source of truth generated in %s\n' "${OUT_DIR}"
