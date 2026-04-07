#!/usr/bin/env bash

set -euo pipefail

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
  dockerfile="services/${service}/Dockerfile"
  context="services/${service}"
  image="${REGISTRY_HOST}/securerag-hub-${service}:${IMAGE_TAG}"

  if [ -f "${dockerfile}" ]; then
    echo "Building ${image}"
    docker build -t "${image}" -f "${dockerfile}" "${context}"
    docker push "${image}"
  else
    echo "Skipping ${service}: Dockerfile missing"
  fi
done
