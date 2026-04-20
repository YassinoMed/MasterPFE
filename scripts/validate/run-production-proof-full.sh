#!/usr/bin/env bash

set -euo pipefail

OUT_DIR="${OUT_DIR:-artifacts/final}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/production-proof-full.md}"
RUN_CLUSTER_MUTATIONS="${RUN_CLUSTER_MUTATIONS:-false}"

mkdir -p "${OUT_DIR}"

status_from_report() {
  local report="$1"
  if [[ -d "${report}" ]]; then
    if find "${report}" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
      printf 'TERMINÉ'
    else
      printf 'PRÊT_NON_EXÉCUTÉ'
    fi
    return 0
  fi
  if [[ ! -s "${report}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi

  local status
  status="$(grep -E '^- Status: `|^Statut global: `' "${report}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: `([^`]+)`.*/\1/' || true)"
  case "${status}" in
    TERMINÉ|PARTIEL|PRÊT_NON_EXÉCUTÉ|DÉPENDANT_DE_L_ENVIRONNEMENT|FAIL)
      printf '%s' "${status}"
      return 0
      ;;
    PARTIAL*|PRESENT_UNPROVEN|PRESENT|FAILED)
      printf 'PARTIEL'
      return 0
      ;;
  esac

  if grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' "${report}"; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  elif grep -Fq 'FAIL' "${report}"; then
    printf 'PARTIEL'
  elif grep -Fq 'PARTIEL' "${report}"; then
    printf 'PARTIEL'
  elif grep -Fq 'PRÊT_NON_EXÉCUTÉ' "${report}"; then
    printf 'PRÊT_NON_EXÉCUTÉ'
  else
    printf 'TERMINÉ'
  fi
}

run_step() {
  local name="$1"
  local report="$2"
  shift
  shift
  local log_file="${OUT_DIR}/production-proof-${name// /-}.log"

  if "$@" >"${log_file}" 2>&1; then
    printf '| %s | %s | `%s`, `%s` |\n' "${name}" "$(status_from_report "${report}")" "${log_file}" "${report}" >> "${OUT_FILE}"
  else
    printf '| %s | PARTIEL | `%s`, `%s` |\n' "${name}" "${log_file}" "${report}" >> "${OUT_FILE}"
  fi
}

{
  printf '# Production Proof Full - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- RUN_CLUSTER_MUTATIONS: `%s`\n\n' "${RUN_CLUSTER_MUTATIONS}"
  printf '| Step | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

run_step "production-cluster-clean" "artifacts/validation/production-cluster-clean.md" bash scripts/validate/validate-production-cluster-clean.sh

if [[ "${RUN_CLUSTER_MUTATIONS}" == "true" ]]; then
  run_step "metrics-hpa-refresh" "artifacts/validation/hpa-runtime-report.md" bash scripts/validate/refresh-hpa-runtime-proof.sh
  run_step "kyverno-audit-install" "artifacts/validation/kyverno-runtime-report.md" bash scripts/deploy/install-kyverno.sh
else
  run_step "hpa-runtime-readonly" "artifacts/validation/hpa-runtime-report.md" bash scripts/validate/validate-hpa-runtime.sh
fi

run_step "kyverno-runtime-proof" "artifacts/validation/kyverno-runtime-report.md" bash scripts/validate/validate-kyverno-runtime.sh
run_step "kyverno-enforce-readiness" "artifacts/validation/kyverno-enforce-readiness.md" bash scripts/validate/validate-kyverno-enforce-readiness.sh
run_step "production-runtime-evidence" "artifacts/validation/production-runtime-evidence.md" bash scripts/validate/collect-production-runtime-evidence.sh
run_step "runtime-image-rollout-proof" "artifacts/validation/runtime-image-rollout-proof.md" bash scripts/validate/validate-runtime-image-rollout.sh
run_step "ha-chaos-lite-readonly" "artifacts/validation/ha-chaos-lite-report.md" bash scripts/validate/validate-ha-chaos-lite.sh
run_step "observability-snapshot" "artifacts/observability/observability-snapshot.md" bash scripts/validate/generate-observability-snapshot.sh
run_step "security-posture" "artifacts/security/security-posture-report.md" bash scripts/validate/generate-security-posture-report.sh
run_step "support-pack" "artifacts/support-pack" bash scripts/validate/build-support-pack.sh

cat >> "${OUT_FILE}" <<'EOF'

## Reading guide

- Default mode avoids cluster mutations.
- Set `RUN_CLUSTER_MUTATIONS=true` to install/repair metrics-server and install Kyverno Audit.
- Pod deletion, rollout restart and node drain remain controlled by `validate-ha-chaos-lite.sh` variables.
EOF

printf '[INFO] Production full proof written to %s\n' "${OUT_FILE}"
