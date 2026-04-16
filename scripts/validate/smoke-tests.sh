#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-curlimages/curl:8.11.1}"
pod_name="curl-smoke-$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/validate/lib/k8s-validation-pod.sh
source "${SCRIPT_DIR}/lib/k8s-validation-pod.sh"

services=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

for service in "${services[@]}"; do
  echo "Checking deployment/${service}..."
  kubectl rollout status "deployment/${service}" -n "${NS}" --timeout=180s
done

echo "Checking health endpoints from inside the cluster..."
kubectl run "${pod_name}" --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --override-type=strategic \
  --overrides="$(validation_pod_overrides "${pod_name}")" \
  --command -- sh -ec '
    for target in \
      http://portal-web:8000/health \
      http://auth-users:8000/health \
      http://chatbot-manager:8000/health \
      http://conversation-service:8000/health \
      http://audit-security-service:8000/health
    do
      echo "GET ${target}"
      curl -fsS --max-time 5 "${target}" >/dev/null
    done
  '
