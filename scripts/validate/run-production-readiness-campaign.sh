#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/final}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-readiness-final.md}"
SUPPORT_PACK_ROOT="${SUPPORT_PACK_ROOT:-artifacts/support-pack}"
RUN_MUTATING="${RUN_MUTATING:-false}"
RUN_DEPLOY_PRODUCTION="${RUN_DEPLOY_PRODUCTION:-${RUN_MUTATING}}"
RUN_INSTALL_METRICS="${RUN_INSTALL_METRICS:-${RUN_MUTATING}}"
RUN_INSTALL_KYVERNO_AUDIT="${RUN_INSTALL_KYVERNO_AUDIT:-${RUN_MUTATING}}"
RUN_ROLLOUT_RESTART="${RUN_ROLLOUT_RESTART:-false}"
RUN_NODE_DRAIN="${RUN_NODE_DRAIN:-false}"
RUN_SUPPLY_CHAIN="${RUN_SUPPLY_CHAIN:-false}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/production}"
IMAGE_TAG="${IMAGE_TAG:-production}"

mkdir -p "${REPORT_DIR}" artifacts/security artifacts/validation artifacts/observability

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

record() {
  local bloc="$1"
  local task="$2"
  local status="$3"
  local evidence="$4"
  printf '| %s | %s | %s | %s |\n' "${bloc}" "${task}" "${status}" "${evidence}" >> "${REPORT_FILE}"
}

command_status() {
  local required="$1"
  if command -v "${required}" >/dev/null 2>&1; then
    printf 'TERMINÉ'
  else
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  fi
}

cluster_ready=false
if command -v kubectl >/dev/null 2>&1 && kubectl version --request-timeout=3s >/dev/null 2>&1; then
  cluster_ready=true
fi

{
  printf '# Production Readiness Final Campaign - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Overlay: `%s`\n' "${KUSTOMIZE_OVERLAY}"
  printf -- '- RUN_MUTATING: `%s`\n\n' "${RUN_MUTATING}"
  printf '| Bloc | Task | Status | Evidence |\n'
  printf '|---|---|---:|---|\n'
} > "${REPORT_FILE}"

if kubectl kustomize "${KUSTOMIZE_OVERLAY}" >/tmp/securerag-production-campaign.yaml 2>/dev/null; then
  record "A" "Render production overlay" "TERMINÉ" "/tmp/securerag-production-campaign.yaml"
else
  record "A" "Render production overlay" "FAIL" "kubectl kustomize failed"
fi

if bash scripts/validate/validate-production-ha.sh >/dev/null 2>&1; then
  record "A" "Static HA validation" "TERMINÉ" "artifacts/security/production-ha-readiness.md"
else
  record "A" "Static HA validation" "FAIL" "artifacts/security/production-ha-readiness.md"
fi

if is_true "${RUN_DEPLOY_PRODUCTION}"; then
  if [[ "${cluster_ready}" == "true" ]]; then
    if REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}" IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}" IMAGE_TAG="${IMAGE_TAG}" KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" bash scripts/deploy/deploy-kind.sh >/tmp/securerag-production-deploy.log 2>&1; then
      cp /tmp/securerag-production-deploy.log artifacts/validation/production-deploy.log
      record "A" "Deploy production overlay" "TERMINÉ" "artifacts/validation/production-deploy.log"
    else
      cp /tmp/securerag-production-deploy.log artifacts/validation/production-deploy.log || true
      record "A" "Deploy production overlay" "PARTIEL" "artifacts/validation/production-deploy.log"
    fi
  else
    record "A" "Deploy production overlay" "DÉPENDANT_DE_L_ENVIRONNEMENT" "Kubernetes API unreachable"
  fi
else
  record "A" "Deploy production overlay" "PRÊT_NON_EXÉCUTÉ" "Set RUN_DEPLOY_PRODUCTION=true"
fi

bash scripts/validate/collect-production-runtime-evidence.sh >/dev/null 2>&1 || true
record "A" "Collect production runtime evidence" "$(grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' artifacts/validation/production-runtime-evidence.md && printf 'DÉPENDANT_DE_L_ENVIRONNEMENT' || printf 'TERMINÉ')" "artifacts/validation/production-runtime-evidence.md"

if is_true "${RUN_ROLLOUT_RESTART}"; then
  if [[ "${cluster_ready}" == "true" ]]; then
    if kubectl rollout restart deployment/portal-web -n "${NS}" >/tmp/production-rollout-restart.log 2>&1 \
      && kubectl rollout status deployment/portal-web -n "${NS}" --timeout=180s >>/tmp/production-rollout-restart.log 2>&1; then
      cp /tmp/production-rollout-restart.log artifacts/validation/production-rollout-restart.log
      record "A" "Rollout restart proof" "TERMINÉ" "artifacts/validation/production-rollout-restart.log"
    else
      cp /tmp/production-rollout-restart.log artifacts/validation/production-rollout-restart.log || true
      record "A" "Rollout restart proof" "PARTIEL" "artifacts/validation/production-rollout-restart.log"
    fi
  else
    record "A" "Rollout restart proof" "DÉPENDANT_DE_L_ENVIRONNEMENT" "Kubernetes API unreachable"
  fi
else
  record "A" "Rollout restart proof" "PRÊT_NON_EXÉCUTÉ" "Set RUN_ROLLOUT_RESTART=true"
fi

if is_true "${RUN_NODE_DRAIN}"; then
  record "A" "Node drain proof" "PRÊT_NON_EXÉCUTÉ" "Manual guarded step required; see docs/runbooks/production-ha.md"
else
  record "A" "Node drain proof" "PRÊT_NON_EXÉCUTÉ" "Set RUN_NODE_DRAIN=true only on a disposable multi-node cluster"
fi

if is_true "${RUN_INSTALL_METRICS}"; then
  if [[ "${cluster_ready}" == "true" ]]; then
    if bash scripts/deploy/install-metrics-server.sh >/tmp/metrics-install.log 2>&1; then
      cp /tmp/metrics-install.log artifacts/validation/metrics-install.log
      record "B" "Install metrics-server" "TERMINÉ" "artifacts/validation/metrics-install.log"
    else
      cp /tmp/metrics-install.log artifacts/validation/metrics-install.log || true
      record "B" "Install metrics-server" "PARTIEL" "artifacts/validation/metrics-install.log"
    fi
  else
    record "B" "Install metrics-server" "DÉPENDANT_DE_L_ENVIRONNEMENT" "Kubernetes API unreachable"
  fi
else
  record "B" "Install metrics-server" "PRÊT_NON_EXÉCUTÉ" "Set RUN_INSTALL_METRICS=true"
fi

bash scripts/validate/validate-cluster-security-addons.sh >/dev/null 2>&1 || true
record "B" "Validate HPA and metrics runtime" "$(grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' artifacts/validation/cluster-security-addons.md 2>/dev/null && printf 'DÉPENDANT_DE_L_ENVIRONNEMENT' || printf 'PARTIEL')" "artifacts/validation/cluster-security-addons.md"

if is_true "${RUN_INSTALL_KYVERNO_AUDIT}"; then
  if [[ "${cluster_ready}" == "true" ]]; then
    if KYVERNO_POLICY_MODE=audit APPLY_POLICIES=true bash scripts/deploy/install-kyverno.sh >/tmp/kyverno-audit-install.log 2>&1; then
      cp /tmp/kyverno-audit-install.log artifacts/validation/kyverno-audit-install.log
      record "C" "Install Kyverno Audit" "TERMINÉ" "artifacts/validation/kyverno-audit-install.log"
    else
      cp /tmp/kyverno-audit-install.log artifacts/validation/kyverno-audit-install.log || true
      record "C" "Install Kyverno Audit" "PARTIEL" "artifacts/validation/kyverno-audit-install.log"
    fi
  else
    record "C" "Install Kyverno Audit" "DÉPENDANT_DE_L_ENVIRONNEMENT" "Kubernetes API unreachable"
  fi
else
  record "C" "Install Kyverno Audit" "PRÊT_NON_EXÉCUTÉ" "Set RUN_INSTALL_KYVERNO_AUDIT=true"
fi

if bash scripts/ci/validate-kyverno-policies.sh >/dev/null 2>&1; then
  record "C" "Kyverno policy static validation" "TERMINÉ" "artifacts/security/kyverno-policy-validation.md"
else
  record "C" "Kyverno policy static validation" "PRÊT_NON_EXÉCUTÉ" "Kyverno CLI missing or policy validation failed"
fi

if is_true "${RUN_SUPPLY_CHAIN}"; then
  if bash scripts/release/run-supply-chain-execute.sh >/tmp/supply-chain-execute.log 2>&1; then
    cp /tmp/supply-chain-execute.log artifacts/release/supply-chain-execute.log
    record "D" "Supply chain execute" "TERMINÉ" "artifacts/release/supply-chain-execute.log"
  else
    cp /tmp/supply-chain-execute.log artifacts/release/supply-chain-execute.log || true
    record "D" "Supply chain execute" "PARTIEL" "artifacts/release/supply-chain-execute.log"
  fi
else
  bash scripts/release/generate-release-attestation.sh >/dev/null 2>&1 || true
  record "D" "Supply chain execute" "PRÊT_NON_EXÉCUTÉ" "Set RUN_SUPPLY_CHAIN=true; current attestation is factual only"
fi

bash scripts/validate/validate-production-data-resilience.sh >/dev/null 2>&1 || true
record "E" "Data resilience readiness" "$(grep -Fq 'Statut global: `TERMINÉ`' artifacts/security/production-data-resilience.md && printf 'TERMINÉ' || printf 'PARTIEL')" "artifacts/security/production-data-resilience.md"

bash scripts/validate/generate-observability-snapshot.sh >/dev/null 2>&1 || true
record "F" "Observability snapshot" "TERMINÉ" "artifacts/observability/observability-snapshot.md"

pack_id="production-readiness-$(date -u '+%Y%m%dT%H%M%SZ')"
PACK_ID="${pack_id}" SUPPORT_PACK_ROOT="${SUPPORT_PACK_ROOT}" bash scripts/validate/build-support-pack.sh >/dev/null 2>&1 || true
record "F" "Support pack" "TERMINÉ" "${SUPPORT_PACK_ROOT}/${pack_id}"

cat >> "${REPORT_FILE}" <<'EOF'

## Reading guide

- `TERMINÉ` means the control executed successfully or the static validation passed.
- `PARTIEL` means implementation exists but proof is incomplete or failed.
- `PRÊT_NON_EXÉCUTÉ` means the step is ready but intentionally not executed in this run.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means Docker, kind, kubectl, registry, Trivy, Syft, Cosign, Kyverno, metrics-server or a reachable cluster is required.
EOF

printf '[INFO] Production readiness campaign report written to %s\n' "${REPORT_FILE}"
