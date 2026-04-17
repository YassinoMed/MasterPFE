#!/usr/bin/env bash

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
ALLOW_MISSING_COMPONENTS="${ALLOW_MISSING_COMPONENTS:-false}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

DEFAULT_COMPONENTS=(
  auth-users=services-laravel/auth-users-service
  chatbot-manager=services-laravel/chatbot-manager-service
  conversation-service=services-laravel/conversation-service
  audit-security-service=services-laravel/audit-security-service
  portal-web=platform/portal-web
)

if [[ -n "${COMPONENTS:-}" ]]; then
  # shellcheck disable=SC2206
  COMPONENT_ARRAY=(${COMPONENTS//,/ })
else
  COMPONENT_ARRAY=("${DEFAULT_COMPONENTS[@]}")
fi

for component in "${COMPONENT_ARRAY[@]}"; do
  if [[ "${component}" == *=* ]]; then
    name="${component%%=*}"
    context="${component#*=}"
  else
    context="${component}"
    name="$(basename "${component}")"
    name="${name%-service}"
  fi

  dockerfile="${context}/Dockerfile"
  image="${REGISTRY_HOST}/${IMAGE_PREFIX}-${name}:${IMAGE_TAG}"

  if [ -f "${dockerfile}" ]; then
    echo "Building ${image}"
    docker build -t "${image}" -f "${dockerfile}" "${REPO_ROOT}"
    docker push "${image}"
  else
    if [[ "${ALLOW_MISSING_COMPONENTS}" == "true" ]]; then
      echo "Skipping ${name}: Dockerfile missing"
    else
      echo "Missing Dockerfile for official component ${name}: ${dockerfile}" >&2
      exit 1
    fi
  fi
done
