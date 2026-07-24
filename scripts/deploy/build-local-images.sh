#!/usr/bin/env bash

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
ALLOW_MISSING_COMPONENTS="${ALLOW_MISSING_COMPONENTS:-false}"
ENABLE_PARALLEL_BUILDS="${ENABLE_PARALLEL_BUILDS:-true}"
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

build_single_component() {
  local component="$1"
  local name context dockerfile image cache_image

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
  cache_image="${REGISTRY_HOST}/${IMAGE_PREFIX}-${name}:build-cache"

  if [ -f "${dockerfile}" ]; then
    echo "[INFO] Building ${image} from ${dockerfile}..."
    export BUILDKIT_PROGRESS=plain
    DOCKER_BUILDKIT=1 docker build \
        --progress=plain \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -t "${image}" \
        -f "${dockerfile}" "."
  else
    if [[ "${ALLOW_MISSING_COMPONENTS}" == "true" ]]; then
      echo "Skipping ${name}: Dockerfile missing"
    else
      echo "Missing Dockerfile for official component ${name}: ${dockerfile}" >&2
      exit 1
    fi
  fi
}

export -f build_single_component
export REGISTRY_HOST IMAGE_TAG IMAGE_PREFIX ALLOW_MISSING_COMPONENTS BUILDKIT_PROGRESS=plain

if [[ "${ENABLE_PARALLEL_BUILDS}" == "true" && ${#COMPONENT_ARRAY[@]} -gt 1 ]]; then
  MAX_JOBS="${MAX_CONCURRENT_BUILDS:-2}"
  echo "[INFO] Building ${#COMPONENT_ARRAY[@]} components with parallel concurrency of ${MAX_JOBS}..."
  pids=()
  failed=0
  for component in "${COMPONENT_ARRAY[@]}"; do
    build_single_component "${component}" &
    pids+=($!)
    if [[ ${#pids[@]} -ge ${MAX_JOBS} ]]; then
      wait "${pids[0]}" || failed=$((failed + 1))
      pids=("${pids[@]:1}")
    fi
  done

  for pid in "${pids[@]}"; do
    wait "${pid}" || failed=$((failed + 1))
  done

  if [[ ${failed} -gt 0 ]]; then
    echo "[ERROR] ${failed} image build(s) failed." >&2
    exit 1
  fi
else
  for component in "${COMPONENT_ARRAY[@]}"; do
    build_single_component "${component}"
  done
fi

echo "[INFO] All target Docker images successfully built."
