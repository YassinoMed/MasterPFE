#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-securerag-dev}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"

services=(
  api-gateway
  auth-users
  chatbot-manager
  llm-orchestrator
  security-auditor
  knowledge-hub
)

for service in "${services[@]}"; do
  image="${REGISTRY_HOST}/securerag-hub-${service}:${IMAGE_TAG}"

  if docker image inspect "${image}" >/dev/null 2>&1; then
    echo "Loading ${image} into kind..."
    kind load docker-image "${image}" --name "${CLUSTER_NAME}"
  else
    echo "Skipping ${image} (not found locally)"
  fi
done
