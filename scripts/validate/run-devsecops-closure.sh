#!/usr/bin/env bash

set -Eeuo pipefail

# Expert closure runner for the remaining SecureRAG Hub DevSecOps gaps.
#
# Default behaviour is conservative:
# - read-only for runtime, security, Kyverno, secrets and Jenkins proofs;
# - no cluster deploy mutation unless RUN_DIGEST_DEPLOY=true;
# - no supply-chain mutation unless RUN_SUPPLY_CHAIN=true or auto preflight passes;
# - no PostgreSQL backup/restore unless DB_* environment variables are provided.

NS="${NS:-securerag-hub}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-production}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-production}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/production}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8085}"

RUN_SUPPLY_CHAIN="${RUN_SUPPLY_CHAIN:-auto}"
RUN_DIGEST_DEPLOY="${RUN_DIGEST_DEPLOY:-false}"
RUN_DATA_PROOF="${RUN_DATA_PROOF:-auto}"
RUN_JENKINS_WEBHOOK_PROOF="${RUN_JENKINS_WEBHOOK_PROOF:-auto}"
RUN_JENKINS_CI_PUSH_PROOF="${RUN_JENKINS_CI_PUSH_PROOF:-false}"
RUN_SUPPORT_PACK="${RUN_SUPPORT_PACK:-true}"
STRICT="${STRICT:-false}"

STAMP="${STAMP:-$(date -u '+%Y%m%dT%H%M%SZ')}"
OUT_DIR="${OUT_DIR:-artifacts/final}"
RUN_DIR="${OUT_DIR}/devsecops-closure-${STAMP}"
LOG_DIR="${RUN_DIR}/logs"
SNAPSHOT_DIR="${RUN_DIR}/snapshots"
REPORT_FILE="${RUN_DIR}/devsecops-closure.md"
LATEST_FILE="${OUT_DIR}/devsecops-closure-latest.md"

mkdir -p "${LOG_DIR}" "${SNAPSHOT_DIR}" "${RUN_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

safe_name() {
  printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-'
}

append_result() {
  local block="$1"
  local step="$2"
  local status="$3"
  local evidence="$4"
  local note="$5"

  printf '| %s | %s | %s | `%s` | %s |\n' "${block}" "${step}" "${status}" "${evidence}" "${note}" >> "${REPORT_FILE}"
}

run_step() {
  local block="$1"
  local step="$2"
  shift 2

  local log_file="${LOG_DIR}/$(safe_name "${block}-${step}").log"
  info "${block} - ${step}"

  if "$@" > "${log_file}" 2>&1; then
    append_result "${block}" "${step}" "TERMINÉ" "${log_file}" "Commande terminee"
    return 0
  fi

  append_result "${block}" "${step}" "PARTIEL" "${log_file}" "Voir le log"
  warn "${block} - ${step} partiel. Log: ${log_file}"
  if is_true "${STRICT}"; then
    error "STRICT=true: arret sur ${block} - ${step}"
    exit 1
  fi
}

skip_step() {
  local block="$1"
  local step="$2"
  local status="$3"
  local reason="$4"

  append_result "${block}" "${step}" "${status}" "${REPORT_FILE}" "${reason}"
  warn "${block} - ${step}: ${status} (${reason})"
}

snapshot() {
  local block="$1"
  local step="$2"
  shift 2

  local file="${SNAPSHOT_DIR}/$(safe_name "${block}-${step}").txt"
  if "$@" > "${file}" 2>&1; then
    append_result "${block}" "${step}" "TERMINÉ" "${file}" "Snapshot archive"
  else
    append_result "${block}" "${step}" "PARTIEL" "${file}" "Snapshot incomplet"
    if is_true "${STRICT}"; then
      error "STRICT=true: arret sur snapshot ${block} - ${step}"
      exit 1
    fi
  fi
}

preflight_supply_chain_ready() {
  has_cmd docker &&
  has_cmd trivy &&
  has_cmd syft &&
  has_cmd cosign &&
  [[ -f "${COSIGN_KEY:-infra/jenkins/secrets/cosign.key}" ]] &&
  [[ -f "${COSIGN_PUBLIC_KEY:-infra/jenkins/secrets/cosign.pub}" ]] &&
  [[ -f "${COSIGN_PASSWORD_FILE:-infra/jenkins/secrets/cosign.password}" ]]
}

db_env_ready() {
  [[ -n "${DB_HOST:-}" ]] &&
  [[ -n "${DB_PORT:-}" ]] &&
  [[ -n "${DB_DATABASE:-}" ]] &&
  [[ -n "${DB_USERNAME:-}" ]] &&
  [[ -n "${DB_PASSWORD:-}" ]]
}

jenkins_reachable() {
  has_cmd curl && curl -fsS -o /dev/null "${JENKINS_URL%/}/login"
}

{
  printf '# SecureRAG Hub - DevSecOps Closure Run\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
  printf -- '- Image prefix: `%s`\n' "${IMAGE_PREFIX}"
  printf -- '- Image tag: `%s`\n' "${IMAGE_TAG}"
  printf -- '- Source image tag: `%s`\n' "${SOURCE_IMAGE_TAG}"
  printf -- '- Target image tag: `%s`\n' "${TARGET_IMAGE_TAG}"
  printf -- '- Overlay: `%s`\n' "${KUSTOMIZE_OVERLAY}"
  printf -- '- Jenkins URL: `%s`\n' "${JENKINS_URL}"
  printf -- '- STRICT: `%s`\n\n' "${STRICT}"
  printf '## Résultats\n\n'
  printf '| Bloc | Tâche | État | Preuve | Note |\n'
  printf '|---|---|---:|---|---|\n'
} > "${REPORT_FILE}"

snapshot "Préflight" "Git commit" git rev-parse HEAD
snapshot "Préflight" "Outils" bash -c 'for tool in docker kubectl kind make curl trivy syft cosign python3; do command -v "$tool" >/dev/null 2>&1 && printf "%s\tOK\t%s\n" "$tool" "$(command -v "$tool")" || printf "%s\tMISSING\t-\n" "$tool"; done'
snapshot "Préflight" "Contexte kubectl" bash -c 'kubectl config current-context || true'

run_step "Bloc A" "Preuve runtime imageID / digest" env \
  REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
  DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" REQUIRE_DIGEST_DEPLOY="${REQUIRE_DIGEST_DEPLOY:-false}" \
  make runtime-image-proof
run_step "Bloc A" "Pods récents / logs / events runtime" make production-runtime-evidence
run_step "Bloc A" "Healthchecks portail / services" make portal-service-proof
snapshot "Bloc A" "ImageIDs actifs" bash -c "kubectl get pods -n '${NS}' -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{range .status.containerStatuses[*]}{.image}{\"\\t\"}{.imageID}{\"\\n\"}{end}{end}' || true"

run_step "Bloc B" "Sécurité post-déploiement runtime" make runtime-security-postdeploy
run_step "Bloc B" "Guards Kubernetes" make k8s-resource-guards
run_step "Bloc B" "Hardening statique" make k8s-ultra-hardening
run_step "Bloc B" "Rapport sécurité consolidé" make security-posture

case "${RUN_SUPPLY_CHAIN}" in
  true|TRUE|1|yes|YES|on|ON)
    run_step "Bloc C" "Supply chain execute" env \
      REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
      SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
      REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
      make supply-chain-execute
    ;;
  auto|AUTO)
    if preflight_supply_chain_ready; then
      run_step "Bloc C" "Supply chain execute" env \
        REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
        SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
        REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
        make supply-chain-execute
    else
      skip_step "Bloc C" "Supply chain execute" "DÉPENDANT_DE_L_ENVIRONNEMENT" "Docker/Trivy/Syft/Cosign ou cles Cosign manquants"
    fi
    ;;
  *)
    skip_step "Bloc C" "Supply chain execute" "PRÊT_NON_EXÉCUTÉ" "RUN_SUPPLY_CHAIN=false"
    ;;
esac

run_step "Bloc C" "Attestation release" make release-attestation
run_step "Bloc C" "Provenance SLSA-style" make release-provenance
run_step "Bloc C" "Preuve release stricte" env \
  REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
  SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
  REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
  make release-proof-strict

if is_true "${RUN_DIGEST_DEPLOY}"; then
  run_step "Bloc C" "Déploiement no-rebuild digest strict" env \
    REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${TARGET_IMAGE_TAG}" \
    KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" REPORT_DIR="${REPORT_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
    REQUIRE_DIGEST_DEPLOY=true FORCE_WORKLOAD_ROLLOUT=true STRICT_RUNTIME_IMAGE_PROOF=true \
    DEPLOY_EVIDENCE_FILE="${REPORT_DIR}/no-rebuild-deploy-summary.md" \
    RUNTIME_IMAGE_PROOF_FILE="artifacts/validation/runtime-image-rollout-proof.md" \
    make deploy
else
  skip_step "Bloc C" "Déploiement no-rebuild digest strict" "PRÊT_NON_EXÉCUTÉ" "Action mutative; activer explicitement RUN_DIGEST_DEPLOY=true"
fi

run_step "Bloc D" "Kyverno runtime / PolicyReports" make kyverno-runtime-proof
run_step "Bloc D" "Kyverno Enforce readiness" make kyverno-enforce-readiness
snapshot "Bloc D" "ClusterPolicies" bash -c 'kubectl get clusterpolicy || true'
snapshot "Bloc D" "PolicyReports" bash -c 'kubectl get policyreport -A || true; printf "\n"; kubectl get clusterpolicyreport || true'

run_step "Bloc E" "PostgreSQL externe / secret DB" make production-external-db-readiness
run_step "Bloc E" "PostgreSQL externe / résilience statique" make production-data-resilience
case "${RUN_DATA_PROOF}" in
  true|TRUE|1|yes|YES|on|ON)
    run_step "Bloc E" "Backup / restore PostgreSQL" make data-resilience-proof
    ;;
  auto|AUTO)
    if db_env_ready; then
      run_step "Bloc E" "Backup / restore PostgreSQL" make data-resilience-proof
    else
      skip_step "Bloc E" "Backup / restore PostgreSQL" "DÉPENDANT_DE_L_ENVIRONNEMENT" "DB_HOST/DB_PORT/DB_DATABASE/DB_USERNAME/DB_PASSWORD non definis"
    fi
    ;;
  *)
    skip_step "Bloc E" "Backup / restore PostgreSQL" "PRÊT_NON_EXÉCUTÉ" "RUN_DATA_PROOF=false"
    ;;
esac

run_step "Bloc F" "Secrets management" make secrets-management

case "${RUN_JENKINS_WEBHOOK_PROOF}" in
  true|TRUE|1|yes|YES|on|ON)
    run_step "Bloc F" "Jenkins webhook proof" make jenkins-webhook-proof
    ;;
  auto|AUTO)
    if jenkins_reachable; then
      run_step "Bloc F" "Jenkins webhook proof" make jenkins-webhook-proof
    else
      skip_step "Bloc F" "Jenkins webhook proof" "DÉPENDANT_DE_L_ENVIRONNEMENT" "Jenkins non joignable sur ${JENKINS_URL}"
    fi
    ;;
  *)
    skip_step "Bloc F" "Jenkins webhook proof" "PRÊT_NON_EXÉCUTÉ" "RUN_JENKINS_WEBHOOK_PROOF=false"
    ;;
esac

if is_true "${RUN_JENKINS_CI_PUSH_PROOF}"; then
  run_step "Bloc F" "Jenkins CI pushed commit proof" make jenkins-ci-push-proof
else
  skip_step "Bloc F" "Jenkins CI pushed commit proof" "PRÊT_NON_EXÉCUTÉ" "Necessite un vrai git push et le commit attendu"
fi

run_step "Bloc F" "Source de vérité finale" make final-source-of-truth
run_step "Bloc F" "Résumé final" make final-summary
run_step "Bloc F" "Matrice finale de fermeture" bash scripts/validate/generate-devsecops-closure-matrix.sh

if is_true "${RUN_SUPPORT_PACK}"; then
  run_step "Bloc F" "Support pack final" make support-pack
else
  skip_step "Bloc F" "Support pack final" "PRÊT_NON_EXÉCUTÉ" "RUN_SUPPORT_PACK=false"
fi

{
  printf '\n## Artefacts clés\n\n'
  printf -- '- `artifacts/validation/runtime-image-rollout-proof.md`\n'
  printf -- '- `artifacts/validation/production-runtime-evidence.md`\n'
  printf -- '- `artifacts/security/runtime-security-postdeploy.md`\n'
  printf -- '- `artifacts/release/release-attestation.md`\n'
  printf -- '- `artifacts/release/provenance.slsa.md`\n'
  printf -- '- `artifacts/validation/kyverno-runtime-report.md`\n'
  printf -- '- `artifacts/security/production-external-db-readiness.md`\n'
  printf -- '- `artifacts/security/production-data-resilience.md`\n'
  printf -- '- `artifacts/security/secrets-management.md`\n'
  printf -- '- `artifacts/security/external-secrets-runtime.md`\n'
  printf -- '- `artifacts/final/devsecops-closure-matrix.md`\n'
  printf -- '- `artifacts/final/final-validation-summary.md`\n'
  printf '\n## Lecture honnête\n\n'
  printf -- '- `TERMINÉ` signifie prouvé dans cette exécution.\n'
  printf -- '- `PARTIEL` signifie qu’une preuve a été rejouée mais reste incomplète ou en échec.\n'
  printf -- '- `PRÊT_NON_EXÉCUTÉ` signifie que le dépôt est prêt mais que l’action mutative n’a pas été rejouée.\n'
  printf -- '- `DÉPENDANT_DE_L_ENVIRONNEMENT` signifie qu’il manque le cluster, Jenkins, la registry ou la base externe.\n'
} >> "${REPORT_FILE}"

cp "${REPORT_FILE}" "${LATEST_FILE}"
printf '[INFO] DevSecOps closure report written to %s\n' "${REPORT_FILE}"
