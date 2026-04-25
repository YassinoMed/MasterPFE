#!/usr/bin/env bash

set -euo pipefail

OUT="${OUT:-artifacts/final/expert-readiness-report.md}"
DOC_OUT="${DOC_OUT:-docs/security/expert-readiness.md}"

mkdir -p "$(dirname "${OUT}")" "$(dirname "${DOC_OUT}")"

status_from_file() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi
  local status
  status="$(grep -E '^- Status: `|^Statut global: `' "${file}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: `([^`]+)`.*/\1/' || true)"
  case "${status}" in
    TERMINÉ|PARTIEL|PRÊT_NON_EXÉCUTÉ|DÉPENDANT_DE_L_ENVIRONNEMENT|FAIL|"TERMINÉ AVEC DÉPENDANCE JENKINS LIVE")
      printf '%s' "${status}"
      return 0
      ;;
  esac
  if grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' "${file}"; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  elif grep -Eq 'PARTIEL|FAIL|FAILED' "${file}"; then
    printf 'PARTIEL'
  elif grep -Fq 'PRÊT_NON_EXÉCUTÉ' "${file}"; then
    printf 'PRÊT_NON_EXÉCUTÉ'
  else
    printf 'TERMINÉ'
  fi
}

merge_status() {
  local status
  for status in "$@"; do
    [[ "${status}" == "PARTIEL" || "${status}" == "FAIL" ]] && { printf 'PARTIEL'; return 0; }
  done
  for status in "$@"; do
    [[ "${status}" == "DÉPENDANT_DE_L_ENVIRONNEMENT" ]] && { printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'; return 0; }
  done
  for status in "$@"; do
    [[ "${status}" == "PRÊT_NON_EXÉCUTÉ" ]] && { printf 'PRÊT_NON_EXÉCUTÉ'; return 0; }
  done
  printf 'TERMINÉ'
}

official_scope="$(status_from_file artifacts/final/official-scope-report.md)"
runtime_image="$(status_from_file artifacts/validation/runtime-image-rollout-proof.md)"
hpa="$(status_from_file artifacts/validation/hpa-runtime-report.md)"
kyverno_runtime="$(status_from_file artifacts/validation/kyverno-runtime-report.md)"
kyverno_enforce="$(status_from_file artifacts/validation/kyverno-enforce-proof.md)"
supply_chain="$(status_from_file artifacts/release/supply-chain-gate-report.md)"
gitops="$(status_from_file artifacts/gitops/argocd-sync.md)"
observability="$(status_from_file artifacts/observability/slo-summary.md)"
secrets="$(status_from_file artifacts/security/secrets-management.md)"
backup="$(status_from_file artifacts/security/production-data-resilience.md)"
chaos="$(status_from_file artifacts/validation/chaos-lite-proof.md)"
runtime_detection="$(status_from_file artifacts/security/runtime-detection-proof.md)"
jenkins="$(status_from_file artifacts/validation/jenkins-webhook-proof.md)"
ci_authority="$(status_from_file artifacts/final/ci-authority-report.md)"
summary="$(status_from_file artifacts/final/final-validation-summary.md)"

global_status="$(merge_status \
  "${official_scope}" "${runtime_image}" "${hpa}" "${kyverno_runtime}" \
  "${supply_chain}" "${observability}" "${secrets}" "${backup}" "${ci_authority}")"

{
  printf '# Expert Readiness Report - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n\n' "${global_status}"

  printf '## 1. Global state\n\n'
  printf 'SecureRAG Hub is an advanced production-like DevSecOps/Kubernetes platform for the official Laravel-first scope. The expert level is reached when the environment-dependent runtime proofs are replayed on the target kind/VPS cluster and all referenced artifacts are current.\n\n'

  printf '## 2. Completed / evidenced domains\n\n'
  printf '| Domain | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Official Laravel scope and legacy exclusion | %s | `artifacts/final/official-scope-report.md` |\n' "${official_scope}"
  printf '| Runtime immutable image rollout | %s | `artifacts/validation/runtime-image-rollout-proof.md` |\n' "${runtime_image}"
  printf '| HPA and metrics-server | %s | `artifacts/validation/hpa-runtime-report.md` |\n' "${hpa}"
  printf '| Kyverno Audit runtime | %s | `artifacts/validation/kyverno-runtime-report.md` |\n' "${kyverno_runtime}"
  printf '| Supply chain gate | %s | `artifacts/release/supply-chain-gate-report.md` |\n' "${supply_chain}"
  printf '| Observability SLO stack | %s | `artifacts/observability/slo-summary.md` |\n' "${observability}"
  printf '| Secrets management | %s | `artifacts/security/secrets-management.md` |\n' "${secrets}"
  printf '| Data resilience | %s | `artifacts/security/production-data-resilience.md` |\n' "${backup}"
  printf '| CI authority | %s | `artifacts/final/ci-authority-report.md` |\n' "${ci_authority}"

  printf '\n## 3. Dependent / optional domains\n\n'
  printf '| Domain | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Jenkins live API/SCM | %s | `artifacts/validation/jenkins-webhook-proof.md` |\n' "${jenkins}"
  printf '| Kyverno Enforce admission | %s | `artifacts/validation/kyverno-enforce-proof.md` |\n' "${kyverno_enforce}"
  printf '| GitOps Argo CD sync | %s | `artifacts/gitops/argocd-sync.md` |\n' "${gitops}"
  printf '| Chaos lite | %s | `artifacts/validation/chaos-lite-proof.md` |\n' "${chaos}"
  printf '| Runtime detection Falco/Tetragon | %s | `artifacts/security/runtime-detection-proof.md` |\n' "${runtime_detection}"
  printf '| Final summary | %s | `artifacts/final/final-validation-summary.md` |\n' "${summary}"

  printf '\n## 4. Honest limits\n\n'
  printf -- '- The official runtime is Laravel-first; historical Python/RAG is not a proven deployed RAG pipeline.\n'
  printf -- '- Jenkins live proof depends on API token validity, job name and permissions.\n'
  printf -- '- Argo CD, Falco, Prometheus/Grafana/Loki and external PostgreSQL require target-cluster resources.\n'
  printf -- '- Destructive or mutative tests remain guarded by explicit `CONFIRM_*` variables.\n'

  printf '\n## 5. Cloud recommendations\n\n'
  printf -- '- Replace kind with a managed Kubernetes cluster or a hardened multi-node VPS cluster.\n'
  printf -- '- Use a managed registry and keep image references immutable by digest.\n'
  printf -- '- Use managed PostgreSQL with automated snapshots and regularly tested restore.\n'
  printf -- '- Move secrets to SOPS/age for GitOps or ESO/Vault for operator-managed environments.\n'
  printf -- '- Keep Jenkins as CI/supply-chain authority and Argo CD as CD/sync authority.\n'

  printf '\n## 6. Final note\n\n'
  printf 'The platform is strong enough for an expert academic DevSecOps defense when the final support pack contains the current artifacts listed above and each non-executed item is presented with its honest status.\n'
} > "${OUT}"

cp "${OUT}" "${DOC_OUT}"
printf '[INFO] Expert readiness report written to %s\n' "${OUT}"
