#!/usr/bin/env bash

set -Eeuo pipefail

# SecureRAG Hub DevSecOps system proof runner.
#
# This script is intended for a production-like VPS/kind environment. It gathers
# concrete DevSecOps evidence without exposing secrets.
#
# Default behavior:
# - read-only for Kubernetes runtime checks, except optional addon refresh;
# - supply-chain execution runs automatically only when required tools and
#   Cosign key files are present;
# - digest deployment runs automatically only when promotion digests exist;
# - PostgreSQL backup/restore runs only when DB_* environment variables exist.

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
PORTAL_HEALTH_URL="${PORTAL_HEALTH_URL:-http://127.0.0.1:8081/health}"

RUN_ADDON_REFRESH="${RUN_ADDON_REFRESH:-true}"
RUN_SUPPLY_CHAIN="${RUN_SUPPLY_CHAIN:-auto}"
RUN_DIGEST_DEPLOY="${RUN_DIGEST_DEPLOY:-auto}"
RUN_DATA_PROOF="${RUN_DATA_PROOF:-auto}"
RUN_SUPPORT_PACK="${RUN_SUPPORT_PACK:-true}"
STRICT="${STRICT:-false}"

STAMP="${STAMP:-$(date -u '+%Y%m%dT%H%M%SZ')}"
OUT_ROOT="${OUT_ROOT:-artifacts/final/devsecops-system-proof-${STAMP}}"
LOG_DIR="${OUT_ROOT}/logs"
SNAPSHOT_DIR="${OUT_ROOT}/snapshots"
SUMMARY_FILE="${OUT_ROOT}/devsecops-system-proof.md"

mkdir -p "${LOG_DIR}" "${SNAPSHOT_DIR}" "${REPORT_DIR}" "${SBOM_DIR}"

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

  printf '| %s | %s | %s | `%s` | %s |\n' \
    "${block}" "${step}" "${status}" "${evidence}" "${note}" >> "${SUMMARY_FILE}"
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

  return 0
}

skip_step() {
  local block="$1"
  local step="$2"
  local status="$3"
  local reason="$4"

  append_result "${block}" "${step}" "${status}" "${SUMMARY_FILE}" "${reason}"
  warn "${block} - ${step}: ${status} (${reason})"
}

capture() {
  local block="$1"
  local step="$2"
  shift 2

  local file="${SNAPSHOT_DIR}/$(safe_name "${block}-${step}").txt"
  info "Snapshot ${block} - ${step}"

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

tool_list_status() {
  local file="${SNAPSHOT_DIR}/preflight-tools.txt"
  : > "${file}"
  for tool in docker kubectl kind make curl trivy syft cosign python3; do
    if has_cmd "${tool}"; then
      printf '%s\tOK\t%s\n' "${tool}" "$(command -v "${tool}")" >> "${file}"
    else
      printf '%s\tMISSING\t-\n' "${tool}" >> "${file}"
    fi
  done
  append_result "Preflight" "Outils locaux" "TERMINÉ" "${file}" "Les outils manquants rendent certains blocs dependants de l'environnement"
}

write_header() {
  {
    printf '# SecureRAG Hub - DevSecOps System Proof\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Namespace: `%s`\n' "${NS}"
    printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
    printf -- '- Image prefix: `%s`\n' "${IMAGE_PREFIX}"
    printf -- '- Image tag: `%s`\n' "${IMAGE_TAG}"
    printf -- '- Source image tag: `%s`\n' "${SOURCE_IMAGE_TAG}"
    printf -- '- Target image tag: `%s`\n' "${TARGET_IMAGE_TAG}"
    printf -- '- Kustomize overlay: `%s`\n' "${KUSTOMIZE_OVERLAY}"
    printf -- '- Portal health URL: `%s`\n' "${PORTAL_HEALTH_URL}"
    printf -- '- STRICT: `%s`\n\n' "${STRICT}"
    printf '## Execution results\n\n'
    printf '| Bloc | Test | Etat | Preuve | Note |\n'
    printf '|---|---|---:|---|---|\n'
  } > "${SUMMARY_FILE}"
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

wait_hpa_without_unknown() {
  local attempts="${HPA_WAIT_ATTEMPTS:-12}"
  local sleep_seconds="${HPA_WAIT_SLEEP_SECONDS:-20}"
  local hpa_file="${SNAPSHOT_DIR}/hpa-convergence.txt"

  : > "${hpa_file}"
  for attempt in $(seq 1 "${attempts}"); do
    {
      printf '\n# Attempt %s/%s at %s\n' "${attempt}" "${attempts}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
      kubectl get hpa -n "${NS}"
    } >> "${hpa_file}" 2>&1 || true

    if kubectl get hpa -n "${NS}" 2>/dev/null | grep -q '<unknown>'; then
      sleep "${sleep_seconds}"
    else
      cat "${hpa_file}"
      return 0
    fi
  done

  cat "${hpa_file}"
  return 1
}

kyverno_reports_present() {
  local file="${SNAPSHOT_DIR}/kyverno-policyreports.txt"
  local namespaced_count="0"
  local cluster_count="0"

  {
    printf '# Kyverno PolicyReports\n\n'
    kubectl get policyreport -A || true
    printf '\n# ClusterPolicyReports\n\n'
    kubectl get clusterpolicyreport || true
  } > "${file}" 2>&1

  namespaced_count="$(kubectl get policyreport -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  cluster_count="$(kubectl get clusterpolicyreport --no-headers 2>/dev/null | wc -l | tr -d ' ')"

  [[ "${namespaced_count}" != "0" || "${cluster_count}" != "0" ]]
}

copy_key_artifacts() {
  local manifest="${OUT_ROOT}/evidence-manifest.txt"
  {
    printf '# Evidence manifest\n\n'
    printf 'Summary: %s\n' "${SUMMARY_FILE}"
    find artifacts -type f \
      \( -path 'artifacts/validation/*' -o -path 'artifacts/release/*' -o -path 'artifacts/security/*' -o -path 'artifacts/final/*' -o -path 'artifacts/observability/*' -o -path 'artifacts/backup/*' \) \
      2>/dev/null | sort
  } > "${manifest}"
}

write_header

tool_list_status
capture "Preflight" "Docker info" bash -c 'docker info 2>/dev/null | sed -n "1,120p"'
capture "Preflight" "Disk memory" bash -c 'df -h; printf "\n"; free -h'
capture "Kubernetes" "Current context" kubectl config current-context
capture "Kubernetes" "Nodes" kubectl get nodes -o wide
capture "Kubernetes" "Workloads" kubectl get deploy,pods,svc,hpa,pdb -n "${NS}" -o wide
capture "Kubernetes" "Events" kubectl get events -n "${NS}" --sort-by=.lastTimestamp

run_step "Bloc A" "Runtime imageID rollout proof" env \
  NS="${NS}" \
  REGISTRY_HOST="${REGISTRY_HOST}" \
  IMAGE_PREFIX="${IMAGE_PREFIX}" \
  IMAGE_TAG="${IMAGE_TAG}" \
  DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
  REQUIRE_DIGEST_DEPLOY="${REQUIRE_DIGEST_DEPLOY:-false}" \
  REPORT_FILE="artifacts/validation/runtime-image-rollout-proof.md" \
  bash scripts/validate/validate-runtime-image-rollout.sh

capture "Bloc A" "Runtime imageIDs" bash -c \
  "kubectl get pods -n '${NS}' -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{range .status.containerStatuses[*]}{.image}{\"\\t\"}{.imageID}{\"\\n\"}{end}{end}'"

if is_true "${RUN_ADDON_REFRESH}"; then
  run_step "Bloc B" "metrics-server install or repair" make metrics-install
else
  skip_step "Bloc B" "metrics-server install or repair" "PRÊT_NON_EXÉCUTÉ" "RUN_ADDON_REFRESH=false"
fi

capture "Bloc B" "kubectl top nodes" kubectl top nodes
capture "Bloc B" "kubectl top pods" kubectl top pods -n "${NS}"
run_step "Bloc B" "HPA without unknown" wait_hpa_without_unknown
run_step "Bloc B" "HPA runtime report" make hpa-runtime-proof

capture "Bloc D" "Kyverno pods" kubectl get pods -n kyverno -o wide
capture "Bloc D" "Kyverno policies" kubectl get clusterpolicy
capture "Bloc D" "Kyverno CRDs" bash -c "kubectl get crd | grep -E 'kyverno.io|wgpolicyk8s.io|reports.kyverno.io|policies.kyverno.io'"
run_step "Bloc D" "Kyverno runtime report" make kyverno-runtime-proof
run_step "Bloc D" "Kyverno enforce readiness" make kyverno-enforce-readiness
run_step "Bloc D" "PolicyReports present" kyverno_reports_present

case "${RUN_SUPPLY_CHAIN}" in
  true|TRUE|1|yes|YES|on|ON)
    run_step "Bloc C" "Supply chain execute" env \
      REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
      SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
      REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
      make supply-chain-execute
    run_step "Bloc C" "Strict release proof" env \
      REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
      SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
      REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
      make release-proof-strict
    ;;
  auto|AUTO)
    if preflight_supply_chain_ready; then
      run_step "Bloc C" "Supply chain execute" env \
        REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
        SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
        REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
        make supply-chain-execute
      run_step "Bloc C" "Strict release proof" env \
        REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
        SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
        REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
        make release-proof-strict
    else
      skip_step "Bloc C" "Supply chain execute" "DÉPENDANT_DE_L_ENVIRONNEMENT" "Docker/Trivy/Syft/Cosign ou cles Cosign manquants"
      run_step "Bloc C" "Supply chain evidence consolidation" make supply-chain-evidence
      run_step "Bloc C" "Release attestation from available evidence" make release-attestation
      run_step "Bloc C" "Release provenance from available evidence" make release-provenance
    fi
    ;;
  *)
    skip_step "Bloc C" "Supply chain execute" "PRÊT_NON_EXÉCUTÉ" "RUN_SUPPLY_CHAIN=false"
    run_step "Bloc C" "Supply chain evidence consolidation" make supply-chain-evidence
    ;;
esac

case "${RUN_DIGEST_DEPLOY}" in
  true|TRUE|1|yes|YES|on|ON)
    run_step "Bloc C" "No-rebuild digest deploy" env \
      REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${TARGET_IMAGE_TAG}" \
      KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" REPORT_DIR="${REPORT_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
      REQUIRE_DIGEST_DEPLOY=true FORCE_WORKLOAD_ROLLOUT=true STRICT_RUNTIME_IMAGE_PROOF=true \
      RUNTIME_IMAGE_PROOF_FILE="${REPORT_DIR}/runtime-image-rollout-proof.md" \
      DEPLOY_EVIDENCE_FILE="${REPORT_DIR}/no-rebuild-deploy-summary.md" \
      make deploy
    ;;
  auto|AUTO)
    if [[ -s "${DIGEST_RECORD_FILE}" ]]; then
      run_step "Bloc C" "No-rebuild digest deploy" env \
        REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${TARGET_IMAGE_TAG}" \
        KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" REPORT_DIR="${REPORT_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
        REQUIRE_DIGEST_DEPLOY=true FORCE_WORKLOAD_ROLLOUT=true STRICT_RUNTIME_IMAGE_PROOF=true \
        RUNTIME_IMAGE_PROOF_FILE="${REPORT_DIR}/runtime-image-rollout-proof.md" \
        DEPLOY_EVIDENCE_FILE="${REPORT_DIR}/no-rebuild-deploy-summary.md" \
        make deploy
    else
      skip_step "Bloc C" "No-rebuild digest deploy" "PRÊT_NON_EXÉCUTÉ" "Digest record absent: ${DIGEST_RECORD_FILE}"
    fi
    ;;
  *)
    skip_step "Bloc C" "No-rebuild digest deploy" "PRÊT_NON_EXÉCUTÉ" "RUN_DIGEST_DEPLOY=false"
    ;;
esac

run_step "Bloc E" "Production external DB readiness" make production-external-db-readiness
run_step "Bloc E" "Production data resilience readiness" make production-data-resilience
case "${RUN_DATA_PROOF}" in
  true|TRUE|1|yes|YES|on|ON)
    run_step "Bloc E" "PostgreSQL backup restore proof" make data-resilience-proof
    ;;
  auto|AUTO)
    if db_env_ready; then
      run_step "Bloc E" "PostgreSQL backup restore proof" make data-resilience-proof
    else
      skip_step "Bloc E" "PostgreSQL backup restore proof" "DÉPENDANT_DE_L_ENVIRONNEMENT" "DB_HOST/DB_PORT/DB_DATABASE/DB_USERNAME/DB_PASSWORD non definis"
    fi
    ;;
  *)
    skip_step "Bloc E" "PostgreSQL backup restore proof" "PRÊT_NON_EXÉCUTÉ" "RUN_DATA_PROOF=false"
    ;;
esac

run_step "Bloc F" "Production Dockerfiles" make production-dockerfiles
run_step "Bloc F" "Image size evidence" env REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" make image-size-evidence
run_step "Bloc F" "Secrets management" make secrets-management
run_step "Bloc F" "Security posture" make security-posture

run_step "Bloc G" "Production proof full" make production-proof-full
run_step "Bloc G" "Final source of truth" make final-source-of-truth
run_step "Bloc G" "Final validation summary" make final-summary

if is_true "${RUN_SUPPORT_PACK}"; then
  run_step "Bloc G" "Support pack" make support-pack
else
  skip_step "Bloc G" "Support pack" "PRÊT_NON_EXÉCUTÉ" "RUN_SUPPORT_PACK=false"
fi

copy_key_artifacts

{
  printf '\n## Key evidence paths\n\n'
  printf -- '- Runtime image proof: `artifacts/validation/runtime-image-rollout-proof.md`\n'
  printf -- '- HPA runtime proof: `artifacts/validation/hpa-runtime-report.md`\n'
  printf -- '- Kyverno runtime proof: `artifacts/validation/kyverno-runtime-report.md`\n'
  printf -- '- Kyverno Enforce readiness: `artifacts/validation/kyverno-enforce-readiness.md`\n'
  printf -- '- Supply chain evidence: `artifacts/release/supply-chain-evidence.md`\n'
  printf -- '- Release attestation: `artifacts/release/release-attestation.md`\n'
  printf -- '- Provenance: `artifacts/release/provenance.slsa.md`\n'
  printf -- '- Data resilience: `artifacts/security/production-data-resilience.md`\n'
  printf -- '- External DB readiness: `artifacts/security/production-external-db-readiness.md`\n'
  printf -- '- External Secrets runtime: `artifacts/security/external-secrets-runtime.md`\n'
  printf -- '- Final production status: `artifacts/final/production-final-status.md`\n'
  printf -- '- Final release status: `artifacts/final/release-final-status.md`\n'
  printf -- '- Final security status: `artifacts/final/security-final-status.md`\n'
  printf -- '- Evidence manifest: `%s/evidence-manifest.txt`\n' "${OUT_ROOT}"
  printf '\n## Honest reading\n\n'
  printf -- '- `TERMINÉ` means proven in this run.\n'
  printf -- '- `PARTIEL` means the check ran but found a gap or transient readiness issue.\n'
  printf -- '- `PRÊT_NON_EXÉCUTÉ` means the script intentionally skipped the step.\n'
  printf -- '- `DÉPENDANT_DE_L_ENVIRONNEMENT` means a required external dependency was absent.\n'
} >> "${SUMMARY_FILE}"

printf '\n[INFO] DevSecOps system proof summary: %s\n' "${SUMMARY_FILE}"
printf '[INFO] Logs: %s\n' "${LOG_DIR}"
printf '[INFO] Snapshots: %s\n' "${SNAPSHOT_DIR}"
