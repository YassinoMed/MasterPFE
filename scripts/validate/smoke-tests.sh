#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-${REGISTRY_HOST:-localhost:5001}/securerag-hub-api-gateway:${IMAGE_TAG:-dev}}"
pod_name="curl-smoke-$(date +%s)"

services=(
  ollama
  portal-web
  api-gateway
  auth-users
  chatbot-manager
  llm-orchestrator
  security-auditor
  knowledge-hub
)

echo "Checking statefulset/qdrant..."
kubectl rollout status statefulset/qdrant -n "${NS}" --timeout=300s

for service in "${services[@]}"; do
  echo "Checking deployment/${service}..."
  if [ "${service}" = "ollama" ]; then
    kubectl rollout status "deployment/${service}" -n "${NS}" --timeout=300s
  else
    kubectl rollout status "deployment/${service}" -n "${NS}" --timeout=180s
  fi
done

echo "Checking health endpoints from inside the cluster..."
kubectl run "${pod_name}" --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --command -- python -c '
import urllib.request

targets = [
    "http://qdrant:6333/readyz",
    "http://ollama:11434/api/tags",
    "http://portal-web:8000/health",
]
targets.extend(
    f"http://{svc}:8080/healthz"
    for svc in [
        "api-gateway",
        "auth-users",
        "chatbot-manager",
        "llm-orchestrator",
        "security-auditor",
        "knowledge-hub",
    ]
)

for target in targets:
    with urllib.request.urlopen(target, timeout=5) as response:
        if response.status != 200:
            raise SystemExit(f"{target} returned HTTP {response.status}")
'
