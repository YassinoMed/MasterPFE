#!/usr/bin/env bash

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
ALLOW_MISSING_COMPONENTS="${ALLOW_MISSING_COMPONENTS:-false}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

HOST_REPO_ROOT=""
if command -v docker >/dev/null 2>&1; then
  CONTAINER_ID=$(hostname)
  MOUNTS=$(docker inspect "${CONTAINER_ID}" --format='{{range .Mounts}}{{.Destination}}:{{.Source}} {{end}}' 2>/dev/null || \
           docker inspect securerag-jenkins --format='{{range .Mounts}}{{.Destination}}:{{.Source}} {{end}}' 2>/dev/null || echo "")
  for m in ${MOUNTS}; do
    dest="${m%%:*}"
    src="${m#*:}"
    if [ -n "${dest}" ]; then
      case "${REPO_ROOT}" in
        "$dest"*)
          rel="${REPO_ROOT#${dest}}"
          HOST_REPO_ROOT="${src}${rel}"
          break
          ;;
      esac
    fi
  done
fi
if [ -z "${HOST_REPO_ROOT}" ]; then
  HOST_REPO_ROOT="${REPO_ROOT}"
fi

DEFAULT_COMPONENTS=(
  auth-users=services-laravel/auth-users-service
  chatbot-manager=services-laravel/chatbot-manager-service
  conversation-service=services-laravel/conversation-service
  audit-security-service=services-laravel/audit-security-service
  portal-web=platform/portal-web
  extraire=services/extraire
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
    echo "Building ${image} with BuildKit..."
    export DOCKER_BUILDKIT=1
    
    if [[ "${USE_KANIKO:-false}" == "true" ]]; then
      echo "[INFO] Building with Kaniko..."
      docker run --rm --network host --cgroupns=host -v "${HOST_REPO_ROOT}:/workspace" \
        gcr.io/kaniko-project/executor@sha256:4e7a52dd1f14872430652bb3b027405b8dfd17c4538751c620ac005741ef9698 \
        --context=/workspace \
        --dockerfile="/workspace/${dockerfile}" \
        --destination="${image}" \
        --cache=true \
        --insecure \
        --skip-tls-verify || docker build -t "${image}" -f "${dockerfile}" .
    else
      docker build -t "${image}" -f "${dockerfile}" .
    fi
  else
    if [[ "${ALLOW_MISSING_COMPONENTS}" == "true" ]]; then
      echo "Skipping ${name}: Dockerfile missing"
    else
      echo "Missing Dockerfile for official component ${name}: ${dockerfile}" >&2
      exit 1
    fi
  fi
done
