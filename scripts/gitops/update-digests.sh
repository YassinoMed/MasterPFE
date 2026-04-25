#!/usr/bin/env bash

set -euo pipefail

DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-artifacts/release/promotion-digests-cluster.txt}"
GITOPS_APP_DIR="${GITOPS_APP_DIR:-infra/gitops/apps/securerag-hub}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
REGISTRY_CLUSTER_HOST="${REGISTRY_CLUSTER_HOST:-securerag-registry:5000}"
REPORT_FILE="${REPORT_FILE:-artifacts/gitops/gitops-digest-update.md}"
LEGACY_REPORT_FILE="${LEGACY_REPORT_FILE:-artifacts/gitops/digest-update.md}"

info() { printf '[INFO] %s\n' "$*"; }

mkdir -p "${GITOPS_APP_DIR}" "$(dirname "${REPORT_FILE}")"

if [[ ! -s "${DIGEST_RECORD_FILE}" ]]; then
  {
    printf '# GitOps Digest Update - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `PRÊT_NON_EXÉCUTÉ`\n'
    printf -- '- Digest record: `%s`\n\n' "${DIGEST_RECORD_FILE}"
    printf 'No cluster digest record is available. Run `make cluster-registry-proof` after pushing images to the cluster-reachable registry.\n'
  } > "${REPORT_FILE}"
  cp "${REPORT_FILE}" "${LEGACY_REPORT_FILE}"
  info "GitOps digest update report written to ${REPORT_FILE}"
  exit 0
fi

tmp_file="$(mktemp)"
{
  printf 'apiVersion: kustomize.config.k8s.io/v1beta1\n'
  printf 'kind: Kustomization\n\n'
  printf 'resources:\n'
  printf '  - ../../../k8s/overlays/production\n\n'
  printf 'images:\n'
  awk -F'|' -v prefix="${IMAGE_PREFIX}" -v registry="${REGISTRY_CLUSTER_HOST}" '
    $0 !~ /^#/ && NF >= 4 {
      service=$1
      target=$3
      digest=$4
      expected=registry "/" prefix "-" service
      if (target != expected) {
        target=expected
      }
      printf "  - name: %s/%s-%s\n", registry, prefix, service
      printf "    newName: %s\n", target
      printf "    digest: %s\n", digest
    }
  ' "${DIGEST_RECORD_FILE}"
} > "${tmp_file}"

mv "${tmp_file}" "${GITOPS_APP_DIR}/kustomization.yaml"

records="$(awk -F'|' '$0 !~ /^#/ && NF >= 4 { count++ } END { print count+0 }' "${DIGEST_RECORD_FILE}")"
{
  printf '# GitOps Digest Update - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "$([[ "${records}" -gt 0 ]] && printf 'TERMINÉ' || printf 'PARTIEL')"
  printf -- '- Digest record: `%s`\n' "${DIGEST_RECORD_FILE}"
  printf -- '- GitOps kustomization: `%s/kustomization.yaml`\n' "${GITOPS_APP_DIR}"
  printf -- '- Registry cluster host: `%s`\n' "${REGISTRY_CLUSTER_HOST}"
  printf -- '- Updated services: `%s`\n\n' "${records}"
  printf 'Jenkins remains the CI and supply-chain authority. This target only updates the GitOps deployment intent with immutable digests.\n'
} > "${REPORT_FILE}"

cp "${REPORT_FILE}" "${LEGACY_REPORT_FILE}"

info "GitOps digest kustomization updated in ${GITOPS_APP_DIR}/kustomization.yaml"
info "GitOps digest update report written to ${REPORT_FILE}"
