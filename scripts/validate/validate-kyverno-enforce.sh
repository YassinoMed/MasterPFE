#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
VALIDATION_SERVICE_ACCOUNT="${VALIDATION_SERVICE_ACCOUNT:-securerag-validation}"
ENFORCE_OVERLAY="${ENFORCE_OVERLAY:-infra/k8s/policies/kyverno-enforce}"
APPLY_ENFORCE="${APPLY_ENFORCE:-false}"
ROLLBACK_TO_AUDIT="${ROLLBACK_TO_AUDIT:-false}"
AUDIT_OVERLAY="${AUDIT_OVERLAY:-infra/k8s/policies/kyverno}"
POSITIVE_IMAGE_DIGEST="${POSITIVE_IMAGE_DIGEST:-}"
NEGATIVE_IMAGE="${NEGATIVE_IMAGE:-nginx:latest}"
CLUSTER_DIGEST_RECORD_FILE="${CLUSTER_DIGEST_RECORD_FILE:-artifacts/release/promotion-digests-cluster.txt}"
REPORT_FILE="${REPORT_FILE:-artifacts/validation/kyverno-enforce-proof.md}"
NEGATIVE_REPORT_FILE="${NEGATIVE_REPORT_FILE:-artifacts/validation/kyverno-admission-negative-test.md}"
STRICT_KYVERNO_ENFORCE="${STRICT_KYVERNO_ENFORCE:-false}"

info() { printf '[INFO] %s\n' "$*"; }
is_true() { case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }

mkdir -p "$(dirname "${REPORT_FILE}")"

write_reports() {
  local status="$1"
  local positive_status="$2"
  local negative_status="$3"
  local decision="$4"
  local negative_detail="$5"

  {
    printf '# Kyverno Enforce Proof - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Enforce overlay: `%s`\n' "${ENFORCE_OVERLAY}"
    printf -- '- Apply Enforce requested: `%s`\n' "${APPLY_ENFORCE}"
    printf -- '- Positive image: `%s`\n\n' "${POSITIVE_IMAGE_DIGEST:-not-resolved}"
    printf '| Gate | Status |\n'
    printf '|---|---:|\n'
    printf '| Enforce policy applied or already active | %s |\n' "${status}"
    printf '| Signed digest admission test | %s |\n' "${positive_status}"
    printf '| Unsigned/latest negative admission test | %s |\n\n' "${negative_status}"
    printf '## Decision\n\n%s\n\n' "${decision}"
    printf '## Rollback\n\nRun `kubectl apply -k %s` to return policies to Audit mode.\n' "${AUDIT_OVERLAY}"
  } > "${REPORT_FILE}"

  {
    printf '# Kyverno Admission Negative Test - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `%s`\n' "${negative_status}"
    printf -- '- Negative image: `%s`\n\n' "${NEGATIVE_IMAGE}"
    printf '## Detail\n\n```text\n%s\n```\n' "${negative_detail}"
  } > "${NEGATIVE_REPORT_FILE}"

  info "Kyverno Enforce proof written to ${REPORT_FILE}"
  info "Kyverno negative admission proof written to ${NEGATIVE_REPORT_FILE}"

  if [[ "${status}" != "TERMINÉ" ]] && is_true "${STRICT_KYVERNO_ENFORCE}"; then
    exit 1
  fi
}

if ! command -v kubectl >/dev/null 2>&1; then
  write_reports "DÉPENDANT_DE_L_ENVIRONNEMENT" "DÉPENDANT_DE_L_ENVIRONNEMENT" "DÉPENDANT_DE_L_ENVIRONNEMENT" "kubectl is required to validate Kyverno Enforce." "kubectl missing"
  exit 0
fi

if is_true "${ROLLBACK_TO_AUDIT}"; then
  kubectl apply -k "${AUDIT_OVERLAY}" >/dev/null
  write_reports "PRÊT_NON_EXÉCUTÉ" "PRÊT_NON_EXÉCUTÉ" "PRÊT_NON_EXÉCUTÉ" "Rollback to Audit overlay was applied on request." "Rollback requested; no negative admission test executed."
  exit 0
fi

if is_true "${APPLY_ENFORCE}"; then
  kubectl apply -k "${ENFORCE_OVERLAY}" >/dev/null
fi

policy_action="$(kubectl get cpol securerag-verify-cosign-images -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null || true)"
verify_digest="$(kubectl get cpol securerag-verify-cosign-images -o jsonpath='{.spec.rules[0].verifyImages[0].verifyDigest}' 2>/dev/null || true)"

if [[ "${policy_action}" != "Enforce" || "${verify_digest}" != "true" ]]; then
  write_reports "PRÊT_NON_EXÉCUTÉ" "PRÊT_NON_EXÉCUTÉ" "PRÊT_NON_EXÉCUTÉ" "Kyverno verifyImages is not in Enforce with verifyDigest=true. Keep Audit until registry, digests and Cosign signatures are proven." "Enforce not active; negative test skipped."
  exit 0
fi

if [[ -z "${POSITIVE_IMAGE_DIGEST}" && -s "${CLUSTER_DIGEST_RECORD_FILE}" ]]; then
  POSITIVE_IMAGE_DIGEST="$(awk -F'|' '$1 == "portal-web" { print $3 "@" $4; exit }' "${CLUSTER_DIGEST_RECORD_FILE}")"
fi

if [[ -z "${POSITIVE_IMAGE_DIGEST}" ]]; then
  write_reports "PARTIEL" "PRÊT_NON_EXÉCUTÉ" "PRÊT_NON_EXÉCUTÉ" "Enforce is active, but no signed digest was provided for the positive admission test." "No negative test executed because the positive digest input is missing."
  exit 0
fi

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}" >/dev/null
kubectl create serviceaccount "${VALIDATION_SERVICE_ACCOUNT}" -n "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl delete pod kyverno-positive-digest-test kyverno-negative-latest-test -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true

positive_output="$(mktemp)"
if cat <<YAML | kubectl apply -f - >"${positive_output}" 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: kyverno-positive-digest-test
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
    - name: app
      image: ${POSITIVE_IMAGE_DIGEST}
      command: ["sh", "-c", "echo kyverno-positive-admission"]
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
  positive_status="TERMINÉ"
else
  positive_status="PARTIEL"
fi
positive_detail="$(cat "${positive_output}")"
rm -f "${positive_output}"

negative_output="$(mktemp)"
if cat <<YAML | kubectl apply -f - >"${negative_output}" 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: kyverno-negative-latest-test
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
    - name: app
      image: ${NEGATIVE_IMAGE}
      command: ["sh", "-c", "echo should-not-run"]
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
  negative_status="PARTIEL"
  negative_detail="$(cat "${negative_output}")"$'\n'"Unexpected: negative pod was admitted."
  kubectl delete pod kyverno-negative-latest-test -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true
else
  negative_status="TERMINÉ"
  negative_detail="$(cat "${negative_output}")"
fi
rm -f "${negative_output}"

kubectl delete pod kyverno-positive-digest-test -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true

if [[ "${positive_status}" == "TERMINÉ" && "${negative_status}" == "TERMINÉ" ]]; then
  write_reports "TERMINÉ" "${positive_status}" "${negative_status}" "Kyverno Enforce accepted a signed digest image and rejected the unsafe negative image." "${negative_detail}"
else
  write_reports "PARTIEL" "${positive_status}" "${negative_status}" "Kyverno Enforce is active, but one admission proof did not match the expected result. Positive detail: ${positive_detail}" "${negative_detail}"
fi
