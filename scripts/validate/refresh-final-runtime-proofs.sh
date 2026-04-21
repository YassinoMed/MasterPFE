#!/usr/bin/env bash

set -Eeuo pipefail

# Final runtime proof refresher for SecureRAG Hub.
#
# Scope:
# - prove runtime image IDs for the official Laravel workloads;
# - install/repair metrics-server and prove HPA metrics without <unknown>;
# - install Kyverno Audit with webhook retry and prove PolicyReports;
# - collect production runtime evidence;
# - regenerate final tables and support pack after real runtime evidence.
#
# Mutating actions:
# - metrics-server install/repair when RUN_METRICS_REFRESH=true;
# - Kyverno Audit install/apply when RUN_KYVERNO_REFRESH=true.
# No workload restart, delete, drain or database mutation is performed here.

NS="${NS:-securerag-hub}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-production}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-artifacts/release/promotion-digests.txt}"
REQUIRE_DIGEST_DEPLOY="${REQUIRE_DIGEST_DEPLOY:-false}"
RUN_METRICS_REFRESH="${RUN_METRICS_REFRESH:-true}"
RUN_KYVERNO_REFRESH="${RUN_KYVERNO_REFRESH:-true}"
RUN_SUPPORT_PACK="${RUN_SUPPORT_PACK:-true}"
STRICT_FINAL_RUNTIME="${STRICT_FINAL_RUNTIME:-false}"
HPA_WAIT_ATTEMPTS="${HPA_WAIT_ATTEMPTS:-15}"
HPA_WAIT_SLEEP_SECONDS="${HPA_WAIT_SLEEP_SECONDS:-20}"
KYVERNO_REPORT_ATTEMPTS="${KYVERNO_REPORT_ATTEMPTS:-12}"
KYVERNO_REPORT_SLEEP_SECONDS="${KYVERNO_REPORT_SLEEP_SECONDS:-30}"

STAMP="${STAMP:-$(date -u '+%Y%m%dT%H%M%SZ')}"
OUT_DIR="${OUT_DIR:-artifacts/final/final-runtime-proof-${STAMP}}"
LOG_DIR="${OUT_DIR}/logs"
SNAPSHOT_DIR="${OUT_DIR}/snapshots"
SUMMARY_FILE="${OUT_DIR}/final-runtime-proof.md"

mkdir -p "${OUT_DIR}" "${LOG_DIR}" "${SNAPSHOT_DIR}" artifacts/validation artifacts/final artifacts/security

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

safe_name() {
  printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-'
}

record() {
  local block="$1"
  local task="$2"
  local status="$3"
  local evidence="$4"
  local note="$5"

  printf '| %s | %s | %s | `%s` | %s |\n' "${block}" "${task}" "${status}" "${evidence}" "${note}" >> "${SUMMARY_FILE}"
}

run_step() {
  local block="$1"
  local task="$2"
  shift 2

  local log_file="${LOG_DIR}/$(safe_name "${block}-${task}").log"
  info "${block} - ${task}"

  if "$@" > "${log_file}" 2>&1; then
    record "${block}" "${task}" "TERMINÉ" "${log_file}" "Commande terminee"
    return 0
  fi

  record "${block}" "${task}" "PARTIEL" "${log_file}" "Voir le log"
  warn "${block} - ${task} partiel. Log: ${log_file}"

  if is_true "${STRICT_FINAL_RUNTIME}"; then
    error "STRICT_FINAL_RUNTIME=true: stopping on ${block} - ${task}"
    exit 1
  fi

  return 0
}

skip_step() {
  local block="$1"
  local task="$2"
  local status="$3"
  local reason="$4"

  record "${block}" "${task}" "${status}" "${SUMMARY_FILE}" "${reason}"
  warn "${block} - ${task}: ${status} (${reason})"
}

snapshot() {
  local block="$1"
  local task="$2"
  shift 2

  local file="${SNAPSHOT_DIR}/$(safe_name "${block}-${task}").txt"
  info "Snapshot ${block} - ${task}"

  if "$@" > "${file}" 2>&1; then
    record "${block}" "${task}" "TERMINÉ" "${file}" "Snapshot archive"
  else
    record "${block}" "${task}" "PARTIEL" "${file}" "Snapshot incomplet"
    if is_true "${STRICT_FINAL_RUNTIME}"; then
      error "STRICT_FINAL_RUNTIME=true: stopping on snapshot ${block} - ${task}"
      exit 1
    fi
  fi
}

wait_for_hpa_metrics() {
  local attempt

  for attempt in $(seq 1 "${HPA_WAIT_ATTEMPTS}"); do
    info "Waiting for HPA metrics without <unknown> (${attempt}/${HPA_WAIT_ATTEMPTS})"
    kubectl get hpa -n "${NS}" -o wide || true

    if kubectl get hpa -n "${NS}" >/dev/null 2>&1 \
      && ! kubectl get hpa -n "${NS}" | grep -q '<unknown>'; then
      return 0
    fi

    sleep "${HPA_WAIT_SLEEP_SECONDS}"
  done

  return 1
}

wait_for_kyverno_reports() {
  local attempt
  local policy_count
  local namespaced_count
  local cluster_count

  for attempt in $(seq 1 "${KYVERNO_REPORT_ATTEMPTS}"); do
    info "Waiting for Kyverno PolicyReports (${attempt}/${KYVERNO_REPORT_ATTEMPTS})"
    kubectl get clusterpolicy || true
    kubectl get policyreport -A || true
    kubectl get clusterpolicyreport || true

    policy_count="$(kubectl get clusterpolicy --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    namespaced_count="$(kubectl get policyreport -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    cluster_count="$(kubectl get clusterpolicyreport --no-headers 2>/dev/null | wc -l | tr -d ' ')"

    if [[ "${policy_count}" != "0" && ( "${namespaced_count}" != "0" || "${cluster_count}" != "0" ) ]]; then
      return 0
    fi

    sleep "${KYVERNO_REPORT_SLEEP_SECONDS}"
  done

  return 1
}

{
  printf '# Final Runtime Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
  printf -- '- Image prefix: `%s`\n' "${IMAGE_PREFIX}"
  printf -- '- Image tag: `%s`\n' "${IMAGE_TAG}"
  printf -- '- Digest record file: `%s`\n' "${DIGEST_RECORD_FILE}"
  printf -- '- Require digest deploy: `%s`\n' "${REQUIRE_DIGEST_DEPLOY}"
  printf -- '- RUN_METRICS_REFRESH: `%s`\n' "${RUN_METRICS_REFRESH}"
  printf -- '- RUN_KYVERNO_REFRESH: `%s`\n' "${RUN_KYVERNO_REFRESH}"
  printf -- '- STRICT_FINAL_RUNTIME: `%s`\n\n' "${STRICT_FINAL_RUNTIME}"
  printf '## Results\n\n'
  printf '| Block | Task | Status | Evidence | Note |\n'
  printf '|---|---|---:|---|---|\n'
} > "${SUMMARY_FILE}"

snapshot "Preflight" "Kubernetes context" kubectl config current-context
snapshot "Preflight" "Nodes" kubectl get nodes -o wide
snapshot "Preflight" "Workloads" kubectl get deploy,pods,svc,hpa,pdb -n "${NS}" -o wide

run_step "Bloc A" "Runtime imageID proof" env \
  NS="${NS}" \
  REGISTRY_HOST="${REGISTRY_HOST}" \
  IMAGE_PREFIX="${IMAGE_PREFIX}" \
  IMAGE_TAG="${IMAGE_TAG}" \
  DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
  REQUIRE_DIGEST_DEPLOY="${REQUIRE_DIGEST_DEPLOY}" \
  REPORT_FILE="artifacts/validation/runtime-image-rollout-proof.md" \
  STRICT_RUNTIME_IMAGE_PROOF=true \
  bash scripts/validate/validate-runtime-image-rollout.sh

snapshot "Bloc A" "Runtime imageIDs" bash -c \
  "kubectl get pods -n '${NS}' -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{range .status.containerStatuses[*]}{.image}{\"\\t\"}{.imageID}{\"\\n\"}{end}{end}'"

if is_true "${RUN_METRICS_REFRESH}"; then
  run_step "Bloc A" "metrics-server install repair" bash scripts/deploy/install-metrics-server.sh
else
  skip_step "Bloc A" "metrics-server install repair" "PRÊT_NON_EXÉCUTÉ" "RUN_METRICS_REFRESH=false"
fi

run_step "Bloc A" "HPA convergence without unknown" wait_for_hpa_metrics
run_step "Bloc A" "Strict HPA runtime report" env NS="${NS}" STRICT=true bash scripts/validate/validate-hpa-runtime.sh
snapshot "Bloc A" "kubectl top nodes" kubectl top nodes
snapshot "Bloc A" "kubectl top pods" kubectl top pods -n "${NS}"
snapshot "Bloc A" "HPA wide" kubectl get hpa -n "${NS}" -o wide

if is_true "${RUN_KYVERNO_REFRESH}"; then
  run_step "Bloc A" "Kyverno Audit install with webhook retry" bash scripts/deploy/install-kyverno.sh
else
  skip_step "Bloc A" "Kyverno Audit install with webhook retry" "PRÊT_NON_EXÉCUTÉ" "RUN_KYVERNO_REFRESH=false"
fi

run_step "Bloc A" "Kyverno PolicyReports ready" wait_for_kyverno_reports
run_step "Bloc A" "Strict Kyverno runtime report" bash scripts/validate/validate-kyverno-runtime.sh
run_step "Bloc A" "Kyverno Enforce readiness report" bash scripts/validate/validate-kyverno-enforce-readiness.sh
snapshot "Bloc A" "Kyverno pods" kubectl get pods -n kyverno -o wide
snapshot "Bloc A" "Kyverno policies reports" bash -c 'kubectl get clusterpolicy; printf "\n"; kubectl get policyreport -A; printf "\n"; kubectl get clusterpolicyreport || true'

run_step "Bloc A" "Production runtime evidence" env NS="${NS}" bash scripts/validate/collect-production-runtime-evidence.sh
run_step "Bloc A" "Runtime security post-deploy" env NS="${NS}" bash scripts/validate/validate-runtime-security-postdeploy.sh
run_step "Bloc A" "Observability snapshot" bash scripts/validate/generate-observability-snapshot.sh
run_step "Bloc A" "Security posture refresh" bash scripts/validate/generate-security-posture-report.sh
run_step "Bloc A" "Final source of truth refresh" bash scripts/validate/generate-final-source-of-truth.sh
run_step "Bloc A" "Final validation summary refresh" bash scripts/validate/generate-final-validation-summary.sh

if is_true "${RUN_SUPPORT_PACK}"; then
  run_step "Bloc A" "Support pack refresh" bash scripts/validate/build-support-pack.sh
else
  skip_step "Bloc A" "Support pack refresh" "PRÊT_NON_EXÉCUTÉ" "RUN_SUPPORT_PACK=false"
fi

{
  printf '\n## Key artifacts\n\n'
  printf -- '- Runtime image proof: `artifacts/validation/runtime-image-rollout-proof.md`\n'
  printf -- '- HPA runtime proof: `artifacts/validation/hpa-runtime-report.md`\n'
  printf -- '- Kyverno runtime proof: `artifacts/validation/kyverno-runtime-report.md`\n'
  printf -- '- Kyverno Enforce readiness: `artifacts/validation/kyverno-enforce-readiness.md`\n'
  printf -- '- Runtime security post-deploy: `artifacts/security/runtime-security-postdeploy.md`\n'
  printf -- '- Kyverno local registry blocker: `artifacts/validation/kyverno-local-registry-enforce-blocker.md`\n'
  printf -- '- Production runtime evidence: `artifacts/validation/production-runtime-evidence.md`\n'
  printf -- '- Observability snapshot: `artifacts/observability/observability-snapshot.md`\n'
  printf -- '- Final validation summary: `artifacts/final/final-validation-summary.md`\n'
  printf -- '- Support pack root: `artifacts/support-pack/`\n'
  printf '\n## Honest reading\n\n'
  printf -- '- `TERMINÉ` means the evidence was generated in this run.\n'
  printf -- '- `PARTIEL` means the command ran but found an incomplete runtime state.\n'
  printf -- '- `PRÊT_NON_EXÉCUTÉ` means an optional mutation was intentionally skipped.\n'
  printf -- '- `DÉPENDANT_DE_L_ENVIRONNEMENT` remains possible only when the cluster or tools are unavailable.\n'
} >> "${SUMMARY_FILE}"

info "Final runtime proof written to ${SUMMARY_FILE}"
