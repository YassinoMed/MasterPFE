#!/usr/bin/env bash

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"

DEFAULT_COMPONENTS=(
  services/api-gateway
  services/auth-users
  services/chatbot-manager
  services/llm-orchestrator
  services/security-auditor
  services/knowledge-hub
  platform/portal-web
)

if [[ -n "${COMPONENTS:-}" ]]; then
  # shellcheck disable=SC2206
  COMPONENT_ARRAY=(${COMPONENTS//,/ })
else
  COMPONENT_ARRAY=("${DEFAULT_COMPONENTS[@]}")
fi

for component in "${COMPONENT_ARRAY[@]}"; do
  name="$(basename "${component}")"
  dockerfile="${component}/Dockerfile"
  context="${component}"
  image="${REGISTRY_HOST}/securerag-hub-${name}:${IMAGE_TAG}"

  if [ -f "${dockerfile}" ]; then
    echo "Building ${image}"
    docker build -t "${image}" -f "${dockerfile}" "${context}"
    docker push "${image}"
  else
    echo "Skipping ${name}: Dockerfile missing"
  fi
done
