#!/usr/bin/env bash

set -euo pipefail

OUT_DIR="${OUT_DIR:-artifacts/final}"
mkdir -p "${OUT_DIR}"

if [[ -x scripts/validate/generate-official-scope-report.sh ]]; then
  bash scripts/validate/generate-official-scope-report.sh >/dev/null || true
fi

status_from_file() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi
  local status
  local fail_count
  local warn_count
  local skip_count
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
  local declared
  declared="$(grep -E '^- Status: `|^Statut global: `' "${file}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: `([^`]+)`.*/\1/' || true)"
  case "${declared}" in
    TERMINÉ|PARTIEL|PRÊT_NON_EXÉCUTÉ|DÉPENDANT_DE_L_ENVIRONNEMENT|FAIL)
      printf '%s' "${declared}"
      return 0
      ;;
  esac
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

prefer_status() {
  local first="$1"
  local second="$2"
  if [[ -s "${first}" ]]; then
    status_from_file "${first}"
  else
    status_from_file "${second}"
  fi
}

prefer_jenkins_status() {
  local first="$1"
  local second="$2"
  if [[ -s "${first}" ]]; then
    jenkins_status_from_file "${first}"
  else
    jenkins_status_from_file "${second}"
  fi
}

attestation_json_status() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi
  python3 - "${file}" <<'PY' 2>/dev/null || { printf 'PARTIEL'; exit 0; }
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
status = data.get("status")
if status == "COMPLETE_PROVEN":
    print("TERMINÉ")
elif status in {"PARTIAL_READY_TO_PROVE", "PRESENT_UNPROVEN"}:
    print("DÉPENDANT_DE_L_ENVIRONNEMENT")
else:
    print("PARTIEL")
PY
}

cluster_digest_status() {
  local file="${1:-artifacts/release/promotion-digests-cluster.txt}"
  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi
  if awk -F'|' '
    $0 !~ /^#/ && NF >= 4 {
      records++
      if ($3 !~ /^securerag-registry:5000\/securerag-hub-/ || $4 !~ /^sha256:[0-9a-f]{64}$/) bad++
    }
    END { exit(records >= 5 && bad == 0 ? 0 : 1) }
  ' "${file}"; then
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
security_kyverno_enforce_status="$(status_from_file artifacts/validation/kyverno-enforce-proof.md)"
security_official_scope_status="$(status_from_file artifacts/final/official-scope-report.md)"
security_jenkins_webhook_status="$(prefer_jenkins_status artifacts/validation/jenkins-webhook-proof.md artifacts/jenkins/github-webhook-validation.md)"
security_jenkins_ci_status="$(prefer_jenkins_status artifacts/validation/jenkins-ci-push-proof.md artifacts/jenkins/ci-push-trigger-proof.md)"
security_global_status="$(merge_status \
  "${security_official_scope_status}" \
  "${security_k8s_hardening_status}" \
  "${security_runtime_status}" \
  "${security_dockerfiles_status}" \
  "${security_secrets_status}" \
  "${security_kyverno_runtime_status}" \
  "${security_kyverno_enforce_status}" \
  "${security_jenkins_webhook_status}" \
  "${security_jenkins_ci_status}")"

production_ha_status="$(status_from_file artifacts/security/production-ha-readiness.md)"
production_external_db_status="$(status_from_file artifacts/security/production-external-db-readiness.md)"
production_runtime_evidence_status="$(status_from_file artifacts/validation/production-runtime-evidence.md)"
production_runtime_security_status="$(status_from_file artifacts/security/runtime-security-postdeploy.md)"
production_runtime_image_status="$(status_from_file artifacts/validation/runtime-image-rollout-proof.md)"
production_hpa_status="$(status_from_file artifacts/validation/hpa-runtime-report.md)"
production_ha_chaos_status="$(prefer_status artifacts/validation/chaos-lite-proof.md artifacts/validation/ha-chaos-lite-report.md)"
production_data_resilience_status="$(status_from_file artifacts/security/production-data-resilience.md)"
production_scheduled_backup_status="$(prefer_status artifacts/backup/scheduled-backup-proof.md artifacts/backup/scheduled-backup-report.md)"
production_cluster_digest_status="$(cluster_digest_status artifacts/release/promotion-digests-cluster.txt)"
production_global_status="$(merge_status \
  "${production_ha_status}" \
  "${production_cluster_digest_status}" \
  "${production_external_db_status}" \
  "${production_runtime_evidence_status}" \
  "${production_runtime_security_status}" \
  "${production_runtime_image_status}" \
  "${production_hpa_status}" \
  "${production_ha_chaos_status}" \
  "${production_scheduled_backup_status}" \
  "${production_data_resilience_status}")"

release_attestation_status="$(attestation_json_status artifacts/release/release-attestation.json)"
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
  printf '| Official scope / legacy exclusion | %s | `artifacts/final/official-scope-report.md` |\n' "${security_official_scope_status}"
  printf '| Kubernetes hardening static | %s | `artifacts/security/k8s-ultra-hardening.md` |\n' "${security_k8s_hardening_status}"
  printf '| Runtime security post-deploy | %s | `artifacts/security/runtime-security-postdeploy.md` |\n' "${security_runtime_status}"
  printf '| Dockerfiles production | %s | `artifacts/security/production-dockerfiles.md` |\n' "${security_dockerfiles_status}"
  printf '| Secrets management | %s | `artifacts/security/secrets-management.md` |\n' "${security_secrets_status}"
  printf '| Kyverno runtime | %s | `artifacts/validation/kyverno-runtime-report.md` |\n' "${security_kyverno_runtime_status}"
  printf '| Kyverno Enforce admission proof | %s | `artifacts/validation/kyverno-enforce-proof.md` |\n' "${security_kyverno_enforce_status}"
  printf '| Jenkins webhook/API proof | %s | `artifacts/validation/jenkins-webhook-proof.md` |\n' "${security_jenkins_webhook_status}"
  printf '| Jenkins CI push proof | %s | `artifacts/validation/jenkins-ci-push-proof.md` |\n' "${security_jenkins_ci_status}"
} > "${security_file}"

{
  printf '# Production Final Status - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n\n' "${production_global_status}"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Production HA static | %s | `artifacts/security/production-ha-readiness.md` |\n' "${production_ha_status}"
  printf '| Cluster registry immutable digests | %s | `artifacts/release/promotion-digests-cluster.txt` |\n' "${production_cluster_digest_status}"
  printf '| External DB overlay / secret DB | %s | `artifacts/security/production-external-db-readiness.md` |\n' "${production_external_db_status}"
  printf '| Runtime evidence | %s | `artifacts/validation/production-runtime-evidence.md` |\n' "${production_runtime_evidence_status}"
  printf '| Runtime security post-deploy | %s | `artifacts/security/runtime-security-postdeploy.md` |\n' "${production_runtime_security_status}"
  printf '| Runtime image rollout | %s | `artifacts/validation/runtime-image-rollout-proof.md` |\n' "${production_runtime_image_status}"
  printf '| HPA runtime | %s | `artifacts/validation/hpa-runtime-report.md` |\n' "${production_hpa_status}"
  printf '| HA chaos lite | %s | `artifacts/validation/chaos-lite-proof.md` |\n' "${production_ha_chaos_status}"
  printf '| Scheduled backup | %s | `artifacts/backup/scheduled-backup-proof.md` |\n' "${production_scheduled_backup_status}"
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
  printf -- '- `artifacts/security/production-external-db-readiness.md`\n'
  printf -- '- `artifacts/security/production-dockerfiles.md`\n'
  printf -- '- `artifacts/security/secrets-management.md`\n'
  printf -- '- `artifacts/security/runtime-security-postdeploy.md`\n'
  printf -- '- `artifacts/validation/hpa-runtime-report.md`\n'
  printf -- '- `artifacts/validation/kyverno-runtime-report.md`\n'
  printf -- '- `artifacts/validation/kyverno-enforce-proof.md`\n'
  printf -- '- `artifacts/validation/jenkins-webhook-proof.md`\n'
  printf -- '- `artifacts/validation/jenkins-ci-push-proof.md`\n'
  printf -- '- `artifacts/final/official-scope-report.md`\n'
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
