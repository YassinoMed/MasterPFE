#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
AUDITOR_URL="${AUDITOR_URL:-http://audit-security-service:8000/health}"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-curlimages/curl:8.11.1}"
pod_name="adversarial-check-$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/validate/lib/k8s-validation-pod.sh
source "${SCRIPT_DIR}/lib/k8s-validation-pod.sh"

echo "Basic adversarial validation bootstrap"
kubectl run "${pod_name}" --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --override-type=strategic \
  --overrides="$(validation_pod_overrides "${pod_name}")" \
  --command -- sh -ec "curl -fsS --max-time 5 '${AUDITOR_URL}' >/dev/null && echo 'Audit Security service basic availability OK'"
