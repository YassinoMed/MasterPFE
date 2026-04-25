#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
VALIDATION_SERVICE_ACCOUNT="${VALIDATION_SERVICE_ACCOUNT:-securerag-validation}"
REGISTRY_CLUSTER_HOST="${REGISTRY_CLUSTER_HOST:-securerag-registry:5000}"
REGISTRY_HOST_SIDE="${REGISTRY_HOST_SIDE:-127.0.0.1:5002}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
DIGEST_TEST_SERVICE="${DIGEST_TEST_SERVICE:-portal-web}"
IMAGE_TAG="${IMAGE_TAG:-production}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-prod}"
REPORT_FILE="${REPORT_FILE:-artifacts/validation/cluster-registry-report.md}"
CLUSTER_DIGEST_RECORD_FILE="${CLUSTER_DIGEST_RECORD_FILE:-artifacts/release/promotion-digests-cluster.txt}"
STRICT_CLUSTER_REGISTRY="${STRICT_CLUSTER_REGISTRY:-false}"

services=(auth-users chatbot-manager conversation-service audit-security-service portal-web)
registry_name="${REGISTRY_CLUSTER_HOST%%:*}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
is_true() { case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }

finish() {
  local status="$1"
  local dns_status="$2"
  local catalog_status="$3"
  local digest_status="$4"
  local detail="$5"

  mkdir -p "$(dirname "${REPORT_FILE}")" "$(dirname "${CLUSTER_DIGEST_RECORD_FILE}")"
  {
    printf '# Cluster Reachable Registry Proof\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Cluster registry: `%s`\n' "${REGISTRY_CLUSTER_HOST}"
    printf -- '- Host registry: `%s`\n' "${REGISTRY_HOST_SIDE}"
    printf -- '- Digest record: `%s`\n\n' "${CLUSTER_DIGEST_RECORD_FILE}"
    printf '| Check | Status |\n'
    printf '|---|---:|\n'
    printf '| DNS from pod | %s |\n' "${dns_status}"
    printf '| Registry catalog from pod | %s |\n' "${catalog_status}"
    printf '| Pull image by digest from cluster | %s |\n\n' "${digest_status}"
    printf '## Detail\n\n%s\n' "${detail}"
  } > "${REPORT_FILE}"

  info "Cluster registry proof written to ${REPORT_FILE}"
  if [[ "${status}" != "TERMINÉ" ]] && is_true "${STRICT_CLUSTER_REGISTRY}"; then
    exit 1
  fi
}

if ! command -v kubectl >/dev/null 2>&1; then
  finish "DÉPENDANT_DE_L_ENVIRONNEMENT" "DÉPENDANT_DE_L_ENVIRONNEMENT" "DÉPENDANT_DE_L_ENVIRONNEMENT" "DÉPENDANT_DE_L_ENVIRONNEMENT" "kubectl is required."
  exit 0
fi

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}" >/dev/null
kubectl create serviceaccount "${VALIDATION_SERVICE_ACCOUNT}" -n "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

wait_for_pod_done() {
  local pod="$1"
  local deadline="${2:-90}"
  local phase

  for _ in $(seq 1 "${deadline}"); do
    phase="$(kubectl get pod "${pod}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    case "${phase}" in
      Succeeded|Failed) printf '%s\n' "${phase}"; return 0 ;;
    esac
    sleep 1
  done
  printf '%s\n' "${phase:-Unknown}"
}

kubectl delete pod registry-dns-test digest-pull-test -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true

dns_apply_output="$(mktemp)"
if cat <<YAML | kubectl apply -f - >"${dns_apply_output}" 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: registry-dns-test
  namespace: ${NAMESPACE}
  labels:
    job-role: validation
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  serviceAccountName: ${VALIDATION_SERVICE_ACCOUNT}
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: curl
      image: curlimages/curl:8.7.1
      command: ["sh", "-c", "getent hosts ${registry_name} && curl -fsS http://${REGISTRY_CLUSTER_HOST}/v2/_catalog"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
          ephemeral-storage: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
          ephemeral-storage: 128Mi
YAML
then
  dns_phase="$(wait_for_pod_done registry-dns-test 90)"
  dns_logs="$(kubectl logs registry-dns-test -n "${NAMESPACE}" 2>&1 || true)"
else
  dns_phase="CreateFailed"
  dns_logs="$(cat "${dns_apply_output}")"
fi
rm -f "${dns_apply_output}"

if [[ "${dns_phase}" == "Succeeded" ]] && grep -Fq '"repositories"' <<<"${dns_logs}"; then
  dns_status="TERMINÉ"
  catalog_status="TERMINÉ"
else
  dns_status="PARTIEL"
  catalog_status="PARTIEL"
fi

resolve_digest_ref() {
  local service="$1"
  local tag
  local image
  local digest_ref

  if [[ -n "${TEST_IMAGE_DIGEST:-}" && "${service}" == "${DIGEST_TEST_SERVICE}" ]]; then
    printf '%s|%s\n' "${IMAGE_TAG}" "${TEST_IMAGE_DIGEST}"
    return 0
  fi

  command -v docker >/dev/null 2>&1 || return 1

  for tag in "${IMAGE_TAG}" "${TARGET_IMAGE_TAG}" production release-prod release-local; do
    image="${REGISTRY_HOST_SIDE}/${IMAGE_PREFIX}-${service}:${tag}"
      digest_ref="$(docker inspect --format='{{index .RepoDigests 0}}' "${image}" 2>/dev/null || true)"
    if [[ -n "${digest_ref}" && "${digest_ref}" != "<no value>" ]]; then
      printf '%s|%s\n' "${tag}" "${digest_ref/${REGISTRY_HOST_SIDE}/${REGISTRY_CLUSTER_HOST}}"
      return 0
    fi
  done
  return 1
}

{
  printf '# service|source_ref|target_ref|digest\n'
  for service in "${services[@]}"; do
    if digest_record="$(resolve_digest_ref "${service}")"; then
      resolved_tag="${digest_record%%|*}"
      digest_ref="${digest_record#*|}"
      digest="${digest_ref##*@}"
      printf '%s|%s|%s|%s\n' \
        "${service}" \
        "${REGISTRY_HOST_SIDE}/${IMAGE_PREFIX}-${service}:${resolved_tag}" \
        "${digest_ref%@*}" \
        "${digest}"
    fi
  done
} > "${CLUSTER_DIGEST_RECORD_FILE}"

if ! portal_digest_record="$(resolve_digest_ref "${DIGEST_TEST_SERVICE}")"; then
  finish "PRÊT_NON_EXÉCUTÉ" "${dns_status}" "${catalog_status}" "PRÊT_NON_EXÉCUTÉ" "No local digest was found for `${DIGEST_TEST_SERVICE}`. Push images first, then rerun this proof."
  exit 0
fi
portal_digest_ref="${portal_digest_record#*|}"

pull_apply_output="$(mktemp)"
if cat <<YAML | kubectl apply -f - >"${pull_apply_output}" 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: digest-pull-test
  namespace: ${NAMESPACE}
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  serviceAccountName: ${VALIDATION_SERVICE_ACCOUNT}
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: digest-pull-test
      image: ${portal_digest_ref}
      command: ["sh", "-c", "echo pulled-by-digest"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
          ephemeral-storage: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
          ephemeral-storage: 128Mi
YAML
then
  pull_phase="$(wait_for_pod_done digest-pull-test 120)"
  pull_logs="$(kubectl logs digest-pull-test -n "${NAMESPACE}" 2>&1 || true)"
else
  pull_phase="CreateFailed"
  pull_logs="$(cat "${pull_apply_output}")"
fi
rm -f "${pull_apply_output}"

if [[ "${pull_phase}" == "Succeeded" ]] && grep -Fq 'pulled-by-digest' <<<"${pull_logs}"; then
  digest_status="TERMINÉ"
else
  digest_status="PARTIEL"
fi

kubectl delete pod registry-dns-test digest-pull-test -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true

if [[ "${dns_status}" == "TERMINÉ" && "${catalog_status}" == "TERMINÉ" && "${digest_status}" == "TERMINÉ" ]]; then
  finish "TERMINÉ" "${dns_status}" "${catalog_status}" "${digest_status}" "Registry DNS, catalog access and digest pull were proven from the cluster."
else
  finish "PARTIEL" "${dns_status}" "${catalog_status}" "${digest_status}" "DNS/catalog logs:\n\n\`\`\`text\n${dns_logs}\n\`\`\`\n\nDigest pull logs:\n\n\`\`\`text\n${pull_logs}\n\`\`\`"
fi
