#!/usr/bin/env bash

set -euo pipefail

# One-command DevSecOps final proof orchestrator for SecureRAG Hub.
#
# Default mode is non-destructive:
# - does not trigger Jenkins;
# - does not sign or promote images;
# - does not install metrics-server or Kyverno;
# - does not mutate the Kubernetes cluster.
#
# Optional execute paths can be enabled explicitly through environment flags.

OUT_DIR="${OUT_DIR:-artifacts/final}"
REPORT_FILE="${REPORT_FILE:-${OUT_DIR}/devsecops-final-proof.md}"
RUN_JENKINS_WEBHOOK_PROOF="${RUN_JENKINS_WEBHOOK_PROOF:-true}"
RUN_CI_PUSH_PROOF="${RUN_CI_PUSH_PROOF:-false}"
RUN_SUPPLY_CHAIN_EXECUTE="${RUN_SUPPLY_CHAIN_EXECUTE:-false}"
RUN_CLUSTER_SECURITY_PROOF="${RUN_CLUSTER_SECURITY_PROOF:-true}"
RUN_CLUSTER_ADDON_INSTALL="${RUN_CLUSTER_ADDON_INSTALL:-false}"
RUN_KYVERNO_ENFORCE="${RUN_KYVERNO_ENFORCE:-false}"
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

run_step() {
  local name="$1"
  local mode="$2"
  shift 2
  local log_file="${OUT_DIR}/$(printf '%s' "${name}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-').log"
  local status="OK"

  info "Running ${name}"
  if "$@" > "${log_file}" 2>&1; then
    status="OK"
  else
    status="PARTIEL"
    warn "${name} did not complete successfully; inspect ${log_file}"
    if is_true "${STRICT}"; then
      status="FAIL"
    fi
  fi

  printf '| %s | %s | %s | `%s` |\n' "${name}" "${mode}" "${status}" "${log_file}" >> "${REPORT_FILE}"

  if [[ "${status}" == "FAIL" ]]; then
    fail "${name} failed in STRICT mode"
  fi
}

skip_step() {
  local name="$1"
  local reason="$2"

  printf '| %s | OPTIONAL | SKIPPED | %s |\n' "${name}" "${reason}" >> "${REPORT_FILE}"
}

{
  printf '# SecureRAG Hub DevSecOps Final Proof\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Official scenario: `demo`\n'
  printf -- '- Default behavior: non-destructive evidence collection\n'
  printf -- '- Strict mode: `%s`\n\n' "${STRICT}"
  printf '## Execution matrix\n\n'
  printf '| Step | Mode | Status | Evidence |\n'
  printf '|---|---:|---:|---|\n'
} > "${REPORT_FILE}"

if is_true "${RUN_JENKINS_WEBHOOK_PROOF}"; then
  run_step "Jenkins webhook readiness" "READ_ONLY" bash scripts/jenkins/validate-github-webhook.sh
else
  skip_step "Jenkins webhook readiness" "Disabled by RUN_JENKINS_WEBHOOK_PROOF=false"
fi

if is_true "${RUN_CI_PUSH_PROOF}"; then
  run_step "Jenkins CI pushed commit proof" "READ_ONLY" bash scripts/jenkins/verify-ci-push-trigger.sh
else
  skip_step "Jenkins CI pushed commit proof" "Requires a real git push and Jenkins API credentials"
fi

run_step "Supply chain evidence consolidation" "READ_ONLY" bash scripts/release/collect-supply-chain-evidence.sh
run_step "Release attestation" "READ_ONLY" bash scripts/release/generate-release-attestation.sh

if is_true "${RUN_SUPPLY_CHAIN_EXECUTE}"; then
  run_step "Supply chain execute" "MUTATING_RELEASE" bash scripts/release/run-supply-chain-execute.sh
else
  skip_step "Supply chain execute" "Disabled; requires Docker registry, images, Syft, Cosign keys"
fi

if is_true "${RUN_CLUSTER_ADDON_INSTALL}"; then
  run_step "metrics-server install" "MUTATING_CLUSTER" bash scripts/deploy/install-metrics-server.sh
  if is_true "${RUN_KYVERNO_ENFORCE}"; then
    run_step "Kyverno enforce install" "MUTATING_CLUSTER" env KYVERNO_POLICY_MODE=enforce bash scripts/deploy/install-kyverno.sh
  else
    run_step "Kyverno audit install" "MUTATING_CLUSTER" bash scripts/deploy/install-kyverno.sh
  fi
else
  skip_step "Cluster addon install" "Disabled; use RUN_CLUSTER_ADDON_INSTALL=true on a disposable/stable cluster"
fi

if is_true "${RUN_CLUSTER_SECURITY_PROOF}"; then
  run_step "Cluster security addon proof" "READ_ONLY" bash scripts/validate/validate-cluster-security-addons.sh
  run_step "Observability snapshot" "READ_ONLY" bash scripts/validate/generate-observability-snapshot.sh
else
  skip_step "Cluster security addon proof" "Disabled by RUN_CLUSTER_SECURITY_PROOF=false"
  skip_step "Observability snapshot" "Disabled by RUN_CLUSTER_SECURITY_PROOF=false"
fi

run_step "Portal service connectivity" "READ_ONLY" bash scripts/validate/validate-portal-service-connectivity.sh
run_step "Global project status" "READ_ONLY" bash scripts/validate/generate-global-project-status.sh
run_step "Final validation summary" "READ_ONLY" bash scripts/validate/generate-final-validation-summary.sh
run_step "DevSecOps readiness report" "READ_ONLY" bash scripts/validate/generate-devsecops-readiness-report.sh

{
  printf '\n## Interpretation\n\n'
  printf -- '- `OK` means the step produced evidence in the current environment.\n'
  printf -- '- `PARTIEL` means the step exists but could not be fully proven in this run.\n'
  printf -- '- `SKIPPED` means the step is intentionally gated to avoid mutating release or cluster state.\n'
  printf -- '- Enable `RUN_SUPPLY_CHAIN_EXECUTE=true` only when images, Cosign keys, Syft and registry are ready.\n'
  printf -- '- Enable `RUN_CLUSTER_ADDON_INSTALL=true` only on a cluster where installing addons is acceptable.\n'
  printf -- '- Enable `RUN_KYVERNO_ENFORCE=true` only after signed images and Audit-mode policies are proven.\n'
} >> "${REPORT_FILE}"

info "DevSecOps final proof written to ${REPORT_FILE}"
