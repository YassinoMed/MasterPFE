#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"

mkdir -p "${REPORT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

capture() {
  local output_file="$1"
  shift

  if "$@" > "${output_file}" 2>&1; then
    info "Captured ${output_file}"
  else
    warn "Command failed while collecting ${output_file}"
  fi
}

capture "${REPORT_DIR}/k8s-get-all.txt" \
  kubectl get all -n "${NS}"

capture "${REPORT_DIR}/k8s-pvc.txt" \
  kubectl get pvc -n "${NS}"

capture "${REPORT_DIR}/k8s-networkpolicy.txt" \
  kubectl get networkpolicy -n "${NS}"

capture "${REPORT_DIR}/k8s-services.txt" \
  kubectl get svc -n "${NS}" -o wide

capture "${REPORT_DIR}/k8s-deployments.txt" \
  kubectl get deploy -n "${NS}" -o wide

capture "${REPORT_DIR}/k8s-pdb.txt" \
  kubectl get pdb -n "${NS}"

capture "${REPORT_DIR}/k8s-hpa.txt" \
  kubectl get hpa -n "${NS}"

capture "${REPORT_DIR}/k8s-resourcequota.txt" \
  kubectl get resourcequota -n "${NS}"

capture "${REPORT_DIR}/k8s-limitrange.txt" \
  kubectl get limitrange -n "${NS}"

capture "${REPORT_DIR}/k8s-metrics-apiservice.txt" \
  kubectl get apiservice v1beta1.metrics.k8s.io -o wide

capture "${REPORT_DIR}/k8s-pods.txt" \
  kubectl get pods -n "${NS}" -o wide

capture "${REPORT_DIR}/portal-web-describe.txt" \
  kubectl describe deploy portal-web -n "${NS}"

for deployment in auth-users chatbot-manager conversation-service audit-security-service; do
  capture "${REPORT_DIR}/${deployment}-describe.txt" \
    kubectl describe deploy "${deployment}" -n "${NS}"
done

capture "${REPORT_DIR}/k8s-events.txt" \
  kubectl get events -n "${NS}" --sort-by=.lastTimestamp

if kubectl top pods -n "${NS}" > /dev/null 2>&1; then
  capture "${REPORT_DIR}/k8s-top-pods.txt" \
    kubectl top pods -n "${NS}"
  capture "${REPORT_DIR}/k8s-top-nodes.txt" \
    kubectl top nodes
else
  warn "metrics-server is not available; skipping kubectl top pods evidence"
fi

if kubectl get ns kyverno > /dev/null 2>&1; then
  capture "${REPORT_DIR}/k8s-kyverno-pods.txt" \
    kubectl get pods -n kyverno -o wide

  if kubectl get clusterpolicy > /dev/null 2>&1; then
    capture "${REPORT_DIR}/k8s-kyverno-policies.txt" \
      kubectl get clusterpolicy

    capture "${REPORT_DIR}/k8s-kyverno-verify-cosign-policy.txt" \
      kubectl describe clusterpolicy securerag-verify-cosign-images
  fi
fi

info "Runtime evidence collection completed in ${REPORT_DIR}"
