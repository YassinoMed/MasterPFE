#!/usr/bin/env bash

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_APP="${ARGOCD_APP:-securerag-hub}"
RUN_DRIFT_TEST="${RUN_DRIFT_TEST:-false}"
DRIFT_NAMESPACE="${DRIFT_NAMESPACE:-securerag-hub}"
DRIFT_DEPLOYMENT="${DRIFT_DEPLOYMENT:-portal-web}"
SYNC_REPORT="${SYNC_REPORT:-artifacts/gitops/argocd-sync.md}"
DRIFT_REPORT="${DRIFT_REPORT:-artifacts/gitops/drift-proof.md}"

is_true() { case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }
info() { printf '[INFO] %s\n' "$*"; }

mkdir -p "$(dirname "${SYNC_REPORT}")"

if ! command -v kubectl >/dev/null 2>&1; then
  sync_status="DÉPENDANT_DE_L_ENVIRONNEMENT"
  sync_detail="kubectl is required."
elif ! kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  sync_status="PRÊT_NON_EXÉCUTÉ"
  sync_detail="Argo CD namespace `${ARGOCD_NAMESPACE}` is not installed."
elif ! kubectl get application "${ARGOCD_APP}" -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  sync_status="PRÊT_NON_EXÉCUTÉ"
  sync_detail="Argo CD Application `${ARGOCD_APP}` is not present."
else
  sync_phase="$(kubectl get application "${ARGOCD_APP}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  health_phase="$(kubectl get application "${ARGOCD_APP}" -n "${ARGOCD_NAMESPACE}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
  sync_detail="sync=${sync_phase:-unknown}; health=${health_phase:-unknown}"
  if [[ "${sync_phase}" == "Synced" && "${health_phase}" == "Healthy" ]]; then
    sync_status="TERMINÉ"
  else
    sync_status="PARTIEL"
  fi
fi

{
  printf '# Argo CD Sync Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "${sync_status}"
  printf -- '- Namespace: `%s`\n' "${ARGOCD_NAMESPACE}"
  printf -- '- Application: `%s`\n\n' "${ARGOCD_APP}"
  printf '## Detail\n\n%s\n' "${sync_detail}"
} > "${SYNC_REPORT}"

if ! is_true "${RUN_DRIFT_TEST}"; then
  {
    printf '# Argo CD Drift Proof - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `PRÊT_NON_EXÉCUTÉ`\n\n'
    printf 'Drift test is intentionally disabled by default. Re-run with `RUN_DRIFT_TEST=true` after Argo CD is installed.\n'
  } > "${DRIFT_REPORT}"
  info "Argo CD sync report written to ${SYNC_REPORT}"
  info "Argo CD drift report written to ${DRIFT_REPORT}"
  exit 0
fi

if [[ "${sync_status}" == "DÉPENDANT_DE_L_ENVIRONNEMENT" || "${sync_status}" == "PRÊT_NON_EXÉCUTÉ" ]]; then
  drift_status="${sync_status}"
  drift_detail="Argo CD is not ready, so drift cannot be tested."
else
  kubectl annotate deployment "${DRIFT_DEPLOYMENT}" -n "${DRIFT_NAMESPACE}" \
    "securerag.dev/drift-proof=$(date -u '+%Y%m%dT%H%M%SZ')" --overwrite >/dev/null

  if command -v argocd >/dev/null 2>&1; then
    if argocd app diff "${ARGOCD_APP}" >/tmp/securerag-argocd-drift.diff 2>&1; then
      drift_status="PARTIEL"
      drift_detail="`argocd app diff` did not report drift after the live annotation mutation."
    else
      drift_status="TERMINÉ"
      drift_detail="$(sed -n '1,160p' /tmp/securerag-argocd-drift.diff)"
    fi
  else
    drift_status="PARTIEL"
    drift_detail="Live annotation drift was created, but the `argocd` CLI is missing. Inspect the Application diff in the UI or install the CLI."
  fi
fi

{
  printf '# Argo CD Drift Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "${drift_status}"
  printf -- '- Deployment mutated for drift: `%s/%s`\n\n' "${DRIFT_NAMESPACE}" "${DRIFT_DEPLOYMENT}"
  printf '## Detail\n\n```text\n%s\n```\n' "${drift_detail}"
} > "${DRIFT_REPORT}"

info "Argo CD sync report written to ${SYNC_REPORT}"
info "Argo CD drift report written to ${DRIFT_REPORT}"
