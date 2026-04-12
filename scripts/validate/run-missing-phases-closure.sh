#!/usr/bin/env bash

set -euo pipefail

# Close the remaining environment-dependent SecureRAG Hub phases.
#
# Default behavior is safe and non-destructive:
# - validates readiness and produces evidence;
# - does not trigger builds;
# - does not sign/promote images;
# - does not install cluster addons.
#
# Mutating or environment-dependent paths must be enabled explicitly.

OUT_DIR="${OUT_DIR:-artifacts/final}"
REPORT_FILE="${REPORT_FILE:-${OUT_DIR}/missing-phases-closure.md}"

RUN_JENKINS_WEBHOOK_PROOF="${RUN_JENKINS_WEBHOOK_PROOF:-true}"
RUN_CI_PUSH_PROOF="${RUN_CI_PUSH_PROOF:-false}"
RUN_SUPPLY_CHAIN_EXECUTE="${RUN_SUPPLY_CHAIN_EXECUTE:-false}"
RUN_CLUSTER_ADDON_INSTALL="${RUN_CLUSTER_ADDON_INSTALL:-false}"
RUN_KYVERNO_ENFORCE="${RUN_KYVERNO_ENFORCE:-false}"
RUN_SUPPORT_PACK="${RUN_SUPPORT_PACK:-true}"
STRICT="${STRICT:-false}"

mkdir -p "${OUT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

slugify() {
  printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-'
}

run_step() {
  local phase="$1"
  local name="$2"
  local mode="$3"
  shift 3

  local log_file="${OUT_DIR}/$(slugify "${phase}-${name}").log"
  local status="OK"

  info "Running ${phase} / ${name}"
  if "$@" > "${log_file}" 2>&1; then
    status="OK"
  else
    status="PARTIEL"
    warn "${phase} / ${name} did not complete successfully; inspect ${log_file}"
    if is_true "${STRICT}"; then
      status="FAIL"
    fi
  fi

  printf '| %s | %s | %s | %s | `%s` |\n' "${phase}" "${name}" "${mode}" "${status}" "${log_file}" >> "${REPORT_FILE}"

  if [[ "${status}" == "FAIL" ]]; then
    fail "${phase} / ${name} failed in STRICT mode"
  fi
}

skip_step() {
  local phase="$1"
  local name="$2"
  local reason="$3"

  printf '| %s | %s | OPTIONAL | SKIPPED | %s |\n' "${phase}" "${name}" "${reason}" >> "${REPORT_FILE}"
}

{
  printf '# Missing Phases Closure - SecureRAG Hub\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Official scenario: `demo`\n'
  printf -- '- Default behavior: safe evidence collection\n'
  printf -- '- Strict mode: `%s`\n\n' "${STRICT}"
  printf '## Execution matrix\n\n'
  printf '| Phase | Step | Mode | Status | Evidence |\n'
  printf '|---|---|---:|---:|---|\n'
} > "${REPORT_FILE}"

if is_true "${RUN_JENKINS_WEBHOOK_PROOF}"; then
  run_step "Phase 1 runtime" "Jenkins webhook readiness" "READ_ONLY" bash scripts/jenkins/validate-github-webhook.sh
else
  skip_step "Phase 1 runtime" "Jenkins webhook readiness" "Disabled by RUN_JENKINS_WEBHOOK_PROOF=false"
fi

if is_true "${RUN_CI_PUSH_PROOF}"; then
  run_step "Phase 1 runtime" "Jenkins pushed commit proof" "READ_ONLY" bash scripts/jenkins/verify-ci-push-trigger.sh
else
  skip_step "Phase 1 runtime" "Jenkins pushed commit proof" "Requires a real git push and Jenkins API credentials"
fi

run_step "Phase 1 runtime" "Portal service connectivity" "READ_ONLY" bash scripts/validate/validate-portal-service-connectivity.sh
run_step "Phase 1 runtime" "Observability snapshot" "READ_ONLY" bash scripts/validate/generate-observability-snapshot.sh

run_step "Phase 2 supply chain" "Evidence consolidation" "READ_ONLY" bash scripts/release/collect-supply-chain-evidence.sh

if is_true "${RUN_SUPPLY_CHAIN_EXECUTE}"; then
  run_step "Phase 2 supply chain" "SBOM Cosign digest no rebuild execute" "MUTATING_RELEASE" bash scripts/release/run-supply-chain-execute.sh
else
  skip_step "Phase 2 supply chain" "SBOM Cosign digest no rebuild execute" "Disabled; requires Docker registry, images, Syft and Cosign keys"
fi

run_step "Phase 2 supply chain" "Release attestation" "READ_ONLY" bash scripts/release/generate-release-attestation.sh

if is_true "${RUN_CLUSTER_ADDON_INSTALL}"; then
  run_step "Phase 3 cluster security" "metrics-server install" "MUTATING_CLUSTER" bash scripts/deploy/install-metrics-server.sh
  if is_true "${RUN_KYVERNO_ENFORCE}"; then
    run_step "Phase 3 cluster security" "Kyverno enforce install" "MUTATING_CLUSTER" env KYVERNO_POLICY_MODE=enforce bash scripts/deploy/install-kyverno.sh
  else
    run_step "Phase 3 cluster security" "Kyverno audit install" "MUTATING_CLUSTER" bash scripts/deploy/install-kyverno.sh
  fi
else
  skip_step "Phase 3 cluster security" "Addon installation" "Disabled; use RUN_CLUSTER_ADDON_INSTALL=true on the target cluster"
fi

run_step "Phase 3 cluster security" "HPA metrics Kyverno reports proof" "READ_ONLY" bash scripts/validate/validate-cluster-security-addons.sh

run_step "Phase 4 closure" "Global project status" "READ_ONLY" bash scripts/validate/generate-global-project-status.sh
run_step "Phase 4 closure" "Final validation summary" "READ_ONLY" bash scripts/validate/generate-final-validation-summary.sh

if is_true "${RUN_SUPPORT_PACK}"; then
  run_step "Phase 4 closure" "Support pack" "READ_ONLY" bash scripts/validate/build-support-pack.sh
else
  skip_step "Phase 4 closure" "Support pack" "Disabled by RUN_SUPPORT_PACK=false"
fi

{
  printf '\n## Reading guide\n\n'
  printf -- '- `OK` means the evidence was generated in the current environment.\n'
  printf -- '- `PARTIEL` means the step exists but the current environment did not satisfy all prerequisites.\n'
  printf -- '- `SKIPPED` means a potentially mutating or external proof was intentionally gated.\n'
  printf -- '- Enable `RUN_CI_PUSH_PROOF=true` only after pushing a commit that Jenkins is expected to consume.\n'
  printf -- '- Enable `RUN_SUPPLY_CHAIN_EXECUTE=true` only when registry images, Syft and Cosign keys are ready.\n'
  printf -- '- Enable `RUN_CLUSTER_ADDON_INSTALL=true` only when mutating the target cluster is acceptable.\n'
  printf -- '- Enable `RUN_KYVERNO_ENFORCE=true` only after Audit mode and signed images are proven.\n'
} >> "${REPORT_FILE}"

info "Missing phases closure report written to ${REPORT_FILE}"
