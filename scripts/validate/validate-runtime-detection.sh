#!/usr/bin/env bash

set -euo pipefail

RUNTIME_SECURITY_NAMESPACE="${RUNTIME_SECURITY_NAMESPACE:-falco}"
REPORT_FILE="${REPORT_FILE:-artifacts/security/runtime-detection-proof.md}"
FALCO_VALUES="${FALCO_VALUES:-infra/runtime-security/falco/values-kind.yaml}"
INSTALL_FALCO="${INSTALL_FALCO:-false}"
CONFIRM_RUNTIME_DETECTION_INSTALL="${CONFIRM_RUNTIME_DETECTION_INSTALL:-NO}"

is_true() { case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }

mkdir -p "$(dirname "${REPORT_FILE}")"

write_report() {
  local status="$1"
  local detail="$2"
  {
    printf '# Runtime Detection Proof - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Falco values: `%s`\n' "${FALCO_VALUES}"
    printf -- '- Namespace: `%s`\n\n' "${RUNTIME_SECURITY_NAMESPACE}"
    printf '## Detail\n\n```text\n%s\n```\n' "${detail}"
    printf '\n## Safety\n\nFalco/Tetragon runtime detection is optional and non-blocking for the official kind/VPS demo. It must remain in audit mode unless capacity is proven.\n'
  } > "${REPORT_FILE}"
}

if [[ ! -s "${FALCO_VALUES}" ]]; then
  write_report "PARTIEL" "Falco values file is missing."
  exit 0
fi

if ! command -v kubectl >/dev/null 2>&1; then
  write_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "kubectl is required for runtime detection proof."
  exit 0
fi

if is_true "${INSTALL_FALCO}"; then
  if [[ "${CONFIRM_RUNTIME_DETECTION_INSTALL}" != "YES" ]]; then
    write_report "PRÊT_NON_EXÉCUTÉ" "Falco install requested but blocked without CONFIRM_RUNTIME_DETECTION_INSTALL=YES."
    exit 0
  fi
  if ! command -v helm >/dev/null 2>&1; then
    write_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "helm is required to install Falco."
    exit 0
  fi
  helm repo add falcosecurity https://falcosecurity.github.io/charts >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm upgrade --install falco falcosecurity/falco \
    --namespace "${RUNTIME_SECURITY_NAMESPACE}" \
    --create-namespace \
    -f "${FALCO_VALUES}" >/tmp/securerag-falco-install.log 2>&1 || {
      write_report "PARTIEL" "$(cat /tmp/securerag-falco-install.log)"
      exit 0
    }
fi

if ! kubectl get namespace "${RUNTIME_SECURITY_NAMESPACE}" >/dev/null 2>&1; then
  write_report "PRÊT_NON_EXÉCUTÉ" "Falco namespace is not installed. Repository-side profile is ready at ${FALCO_VALUES}."
  exit 0
fi

detail="$(
  {
    kubectl get pods,ds,deploy,cm -n "${RUNTIME_SECURITY_NAMESPACE}" 2>&1 || true
    printf '\n--- Falco recent logs ---\n'
    kubectl logs -n "${RUNTIME_SECURITY_NAMESPACE}" -l app.kubernetes.io/name=falco --tail=80 2>&1 || true
  }
)"

if grep -Eiq 'falco.*Running|daemonset.apps/falco|pod/.+falco' <<< "${detail}"; then
  write_report "TERMINÉ" "${detail}"
else
  write_report "PARTIEL" "${detail}"
fi
