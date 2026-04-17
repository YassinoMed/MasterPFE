#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/kyverno-policy-validation.md}"
REQUIRE_KYVERNO_CLI="${REQUIRE_KYVERNO_CLI:-false}"
POLICY_OVERLAY="${POLICY_OVERLAY:-infra/k8s/policies/kyverno}"
RESOURCE_OVERLAY="${RESOURCE_OVERLAY:-infra/k8s/overlays/demo}"

mkdir -p "${REPORT_DIR}"

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

policies_yaml="${tmp_dir}/policies.yaml"
resources_yaml="${tmp_dir}/resources.yaml"
kyverno_log="${REPORT_DIR}/kyverno-apply.log"

kubectl kustomize "${POLICY_OVERLAY}" > "${policies_yaml}"
kubectl kustomize "${RESOURCE_OVERLAY}" > "${resources_yaml}"
bash scripts/validate/validate-k8s-ultra-hardening.sh >/dev/null

{
  printf '# Kyverno Policy Validation - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Policy overlay: `%s`\n' "${POLICY_OVERLAY}"
  printf -- '- Resource overlay: `%s`\n' "${RESOURCE_OVERLAY}"
  printf -- '- Static hardening validation: `TERMINÉ`\n'
} > "${REPORT_FILE}"

if ! command -v kyverno >/dev/null 2>&1; then
  {
    printf -- '- Kyverno CLI: `absent`\n'
    printf -- '- Status: `%s`\n\n' "$(is_true "${REQUIRE_KYVERNO_CLI}" && printf 'FAIL' || printf 'PRÊT_NON_EXÉCUTÉ')"
    printf '## Interpretation\n\n'
    printf 'Kyverno manifests render correctly and static hardening checks pass. Install the Kyverno CLI to execute `kyverno apply` without a cluster.\n'
  } >> "${REPORT_FILE}"

  if is_true "${REQUIRE_KYVERNO_CLI}"; then
    echo "[ERROR] kyverno CLI is required but not installed" >&2
    exit 1
  fi

  echo "[WARN] kyverno CLI not installed; static policy validation completed. Report: ${REPORT_FILE}" >&2
  exit 0
fi

set +e
kyverno apply "${policies_yaml}" --resource "${resources_yaml}" > "${kyverno_log}" 2>&1
kyverno_status=$?
set -e

{
  printf -- '- Kyverno CLI: `present`\n'
  printf -- '- kyverno apply log: `%s`\n' "${kyverno_log}"
  printf -- '- Status: `%s`\n\n' "$([[ "${kyverno_status}" -eq 0 ]] && printf 'TERMINÉ' || printf 'FAIL')"
  printf '## Interpretation\n\n'
  if [[ "${kyverno_status}" -eq 0 ]]; then
    printf '`kyverno apply` accepted the rendered policies against the rendered demo overlay.\n'
  else
    printf '`kyverno apply` reported policy failures. Inspect `%s`.\n' "${kyverno_log}"
  fi
} >> "${REPORT_FILE}"

if [[ "${kyverno_status}" -ne 0 ]]; then
  exit "${kyverno_status}"
fi

echo "[INFO] Kyverno policy validation completed. Report: ${REPORT_FILE}"
