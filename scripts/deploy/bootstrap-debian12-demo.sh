#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

CLUSTER_NAME="${CLUSTER_NAME:-securerag-dev}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-demo}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/demo}"
RUN_FINAL_CAMPAIGN_DRY_RUN="${RUN_FINAL_CAMPAIGN_DRY_RUN:-true}"
RECREATE_CLUSTER="${RECREATE_CLUSTER:-false}"

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_sudo() {
  sudo -v >/dev/null 2>&1 || fail "sudo access is required to install system dependencies"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      fail "Unsupported architecture: $(uname -m)"
      ;;
  esac
}

install_apt_packages() {
  log "Installing Debian packages required by the local demo stack"
  sudo apt-get update
  sudo apt-get install -y \
    bash-completion \
    ca-certificates \
    curl \
    git \
    jq \
    make \
    python3 \
    ruby
}

install_kubectl_if_missing() {
  if command -v kubectl >/dev/null 2>&1; then
    log "kubectl already installed: $(kubectl version --client --output=yaml | awk '/gitVersion:/ {print $2; exit}')"
    return
  fi

  local arch tmpdir stable_version
  arch="$(detect_arch)"
  tmpdir="$(mktemp -d)"
  stable_version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"

  log "Installing kubectl ${stable_version} for ${arch}"
  curl -fsSLo "${tmpdir}/kubectl" "https://dl.k8s.io/release/${stable_version}/bin/linux/${arch}/kubectl"
  chmod +x "${tmpdir}/kubectl"
  sudo install -m 0755 "${tmpdir}/kubectl" /usr/local/bin/kubectl
  rm -rf "${tmpdir}"
}

install_kind_if_missing() {
  if command -v kind >/dev/null 2>&1; then
    log "kind already installed: $(kind version)"
    return
  fi

  local arch tmpdir
  arch="$(detect_arch)"
  tmpdir="$(mktemp -d)"

  log "Installing kind v0.29.0 for ${arch}"
  curl -fsSLo "${tmpdir}/kind" "https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-${arch}"
  chmod +x "${tmpdir}/kind"
  sudo install -m 0755 "${tmpdir}/kind" /usr/local/bin/kind
  rm -rf "${tmpdir}"
}

ensure_docker_ready() {
  command -v docker >/dev/null 2>&1 || fail "docker is required. This script expects a Debian 12 image with Docker already installed."

  if ! docker info >/dev/null 2>&1; then
    fail "docker is installed but not accessible for user $(id -un). Add this user to the docker group or run from a shell that already has Docker access."
  fi

  if ! docker compose version >/dev/null 2>&1; then
    warn "docker compose plugin is not available. Jenkins local startup will be skipped until docker compose is installed."
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "debian" ]]; then
      warn "This script was prepared for Debian 12. Detected ID=${ID:-unknown}."
    fi
    if [[ "${VERSION_ID:-}" != "12" ]]; then
      warn "This script was prepared for Debian 12. Detected VERSION_ID=${VERSION_ID:-unknown}."
    fi
  else
    warn "/etc/os-release not found; continuing without OS verification."
  fi
}

recreate_cluster_if_requested() {
  if [[ "${RECREATE_CLUSTER}" != "true" ]]; then
    return
  fi

  log "Recreating kind cluster ${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}" || true
  docker rm -f kind-registry >/dev/null 2>&1 || true
}

run_demo_stack() {
  log "Creating or reusing the kind cluster"
  bash scripts/deploy/create-kind.sh

  log "Checking cluster access"
  kubectl cluster-info --context "kind-${CLUSTER_NAME}"
  kubectl get nodes

  log "Bootstrapping local secrets"
  bash scripts/secrets/bootstrap-local-secrets.sh
  bash scripts/secrets/create-dev-secrets.sh

  log "Building and pushing demo images to ${REGISTRY_HOST}"
  REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_TAG="${IMAGE_TAG}" bash scripts/deploy/build-local-images.sh

  log "Deploying overlay ${KUSTOMIZE_OVERLAY}"
  REGISTRY_HOST="${REGISTRY_HOST}" \
  IMAGE_PREFIX="${IMAGE_PREFIX}" \
  IMAGE_TAG="${IMAGE_TAG}" \
  KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" \
  bash scripts/deploy/deploy-kind.sh

  log "Printing namespace state"
  kubectl get all -n securerag-hub

  log "Running official smoke tests"
  IMAGE_TAG="${IMAGE_TAG}" bash scripts/validate/smoke-tests.sh

  log "Checking demo endpoints"
  curl -fsS "http://127.0.0.1:8081/health"
  echo
}

run_optional_final_campaign() {
  if [[ "${RUN_FINAL_CAMPAIGN_DRY_RUN}" != "true" ]]; then
    return
  fi

  log "Refreshing the official final campaign in dry-run mode"
  OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run make final-campaign
}

main() {
  check_os
  require_sudo
  install_apt_packages
  ensure_docker_ready
  install_kubectl_if_missing
  install_kind_if_missing
  recreate_cluster_if_requested
  run_demo_stack
  run_optional_final_campaign

  log "SecureRAG Hub demo environment is ready"
  log "Portal Web: http://127.0.0.1:8081/health"
  log "Jenkins can be started later with: docker compose -f infra/jenkins/docker-compose.yml up --build -d"
}

main "$@"
