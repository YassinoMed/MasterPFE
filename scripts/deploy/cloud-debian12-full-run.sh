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
RECREATE_CLUSTER="${RECREATE_CLUSTER:-false}"
INSTALL_ADDONS="${INSTALL_ADDONS:-false}"
START_JENKINS="${START_JENKINS:-true}"
RUN_FINAL_CAMPAIGN_DRY_RUN="${RUN_FINAL_CAMPAIGN_DRY_RUN:-true}"
BUILD_WITH_HOST_NETWORK="${BUILD_WITH_HOST_NETWORK:-auto}"
PUBLIC_HOST="${PUBLIC_HOST:-}"

COMPONENTS=(
  services/api-gateway
  services/auth-users
  services/chatbot-manager
  services/llm-orchestrator
  services/security-auditor
  services/knowledge-hub
  platform/portal-web
)

log() {
  printf '\n[INFO] %s\n' "$*"
}

warn() {
  printf '\n[WARN] %s\n' "$*" >&2
}

fail() {
  printf '\n[ERROR] %s\n' "$*" >&2
  exit 1
}

run() {
  printf '+ %s\n' "$*"
  "$@"
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

install_base_packages() {
  log "Installing base Debian packages"
  run apt-get update
  run apt-get install -y \
    bash-completion \
    ca-certificates \
    curl \
    git \
    iptables \
    jq \
    make \
    python3
}

ensure_docker_access() {
  command -v docker >/dev/null 2>&1 || fail "docker is required before running this script"
  docker info >/dev/null 2>&1 || fail "docker is installed but not accessible from this shell"

  if ! docker compose version >/dev/null 2>&1; then
    log "Installing docker compose plugin"
    run apt-get install -y docker-compose-plugin
  fi
}

repair_docker_networking() {
  log "Enabling Docker bridge forwarding"
  run sysctl -w net.ipv4.ip_forward=1
  printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-securerag-docker.conf
  run iptables -P FORWARD ACCEPT
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

  log "Installing kubectl ${stable_version}"
  run curl -fsSLo "${tmpdir}/kubectl" "https://dl.k8s.io/release/${stable_version}/bin/linux/${arch}/kubectl"
  run chmod +x "${tmpdir}/kubectl"
  run install -m 0755 "${tmpdir}/kubectl" /usr/local/bin/kubectl
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

  log "Installing kind v0.29.0"
  run curl -fsSLo "${tmpdir}/kind" "https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-${arch}"
  run chmod +x "${tmpdir}/kind"
  run install -m 0755 "${tmpdir}/kind" /usr/local/bin/kind
  rm -rf "${tmpdir}"
}

test_docker_egress() {
  log "Testing Docker egress to PyPI"
  if docker run --rm python:3.11-slim-bookworm python - <<'PY'
import urllib.request
print(urllib.request.urlopen("https://pypi.org/simple/pip/", timeout=15).status)
PY
  then
    echo "bridge"
    return 0
  fi

  warn "Docker bridge egress failed; testing host network"
  if docker run --rm --network host python:3.11-slim-bookworm python - <<'PY'
import urllib.request
print(urllib.request.urlopen("https://pypi.org/simple/pip/", timeout=15).status)
PY
  then
    echo "host"
    return 0
  fi

  fail "Docker cannot reach PyPI using bridge or host networking"
}

recreate_cluster_if_requested() {
  if [[ "${RECREATE_CLUSTER}" != "true" ]]; then
    return
  fi

  log "Recreating kind cluster and local registry"
  kind delete cluster --name "${CLUSTER_NAME}" || true
  docker rm -f kind-registry >/dev/null 2>&1 || true
}

create_cluster_and_secrets() {
  log "Creating or reusing kind cluster"
  run bash scripts/deploy/create-kind.sh
  run kubectl cluster-info --context "kind-${CLUSTER_NAME}"
  run kubectl get nodes

  log "Creating local and Kubernetes secrets"
  run bash scripts/secrets/bootstrap-local-secrets.sh
  run bash scripts/secrets/create-dev-secrets.sh
}

build_images_bridge() {
  log "Building demo images with the standard Docker bridge network"
  REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_TAG="${IMAGE_TAG}" bash scripts/deploy/build-local-images.sh
}

build_images_host_network() {
  log "Building demo images with Docker --network host"
  for component in "${COMPONENTS[@]}"; do
    local name image
    name="$(basename "${component}")"
    image="${REGISTRY_HOST}/${IMAGE_PREFIX}-${name}:${IMAGE_TAG}"
    log "Building ${image}"
    run docker build --network host -t "${image}" -f "${component}/Dockerfile" "${component}"
    run docker push "${image}"
  done
}

build_and_push_images() {
  local network_mode

  if [[ "${BUILD_WITH_HOST_NETWORK}" == "true" ]]; then
    build_images_host_network
    return
  fi

  if [[ "${BUILD_WITH_HOST_NETWORK}" == "false" ]]; then
    build_images_bridge
    return
  fi

  network_mode="$(test_docker_egress | tail -n 1)"
  if [[ "${network_mode}" == "bridge" ]]; then
    build_images_bridge
  else
    build_images_host_network
  fi
}

deploy_demo() {
  log "Deploying official demo overlay"
  REGISTRY_HOST="${REGISTRY_HOST}" \
  IMAGE_PREFIX="${IMAGE_PREFIX}" \
  IMAGE_TAG="${IMAGE_TAG}" \
  KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" \
  bash scripts/deploy/deploy-kind.sh

  log "Restarting pods to clear any previous ImagePullBackOff state"
  kubectl delete pod -n securerag-hub --all || true
  kubectl wait --for=condition=Ready pod --all -n securerag-hub --timeout=300s
}

validate_demo() {
  log "Validating demo workloads"
  run kubectl get all -n securerag-hub
  IMAGE_TAG="${IMAGE_TAG}" bash scripts/validate/smoke-tests.sh

  log "Checking local endpoints"
  run curl -fsS "http://127.0.0.1:8080/healthz"
  echo
  run curl -fsS "http://127.0.0.1:8081/health"
  echo
}

install_optional_addons() {
  if [[ "${INSTALL_ADDONS}" != "true" ]]; then
    warn "Skipping metrics-server and Kyverno. Set INSTALL_ADDONS=true to enable them."
    return
  fi

  log "Installing metrics-server"
  bash scripts/deploy/install-metrics-server.sh || warn "metrics-server install/check did not fully pass"

  log "Installing Kyverno policies"
  bash scripts/deploy/install-kyverno.sh || warn "Kyverno install/check did not fully pass"
}

start_jenkins_if_requested() {
  if [[ "${START_JENKINS}" != "true" ]]; then
    warn "Skipping Jenkins startup. Set START_JENKINS=true to enable it."
    return
  fi

  log "Bootstrapping Jenkins credentials and kubeconfig"
  run mkdir -p artifacts/jenkins
  run bash scripts/jenkins/bootstrap-local-credentials.sh
  run bash scripts/jenkins/bootstrap-local-kubeconfig.sh

  log "Building Jenkins image with host networking when needed"
  if ! docker image inspect jenkins-jenkins >/dev/null 2>&1; then
    run docker build --network host -t jenkins-jenkins infra/jenkins
  fi

  log "Starting Jenkins"
  run docker compose -f infra/jenkins/docker-compose.yml up -d
  run docker compose -f infra/jenkins/docker-compose.yml ps

  log "Waiting for Jenkins HTTP endpoint"
  for _ in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:8085/login" >/dev/null; then
      log "Jenkins is reachable on http://127.0.0.1:8085"
      return
    fi
    sleep 5
  done

  fail "Jenkins did not become reachable on http://127.0.0.1:8085"
}

run_final_campaign_dry_run() {
  if [[ "${RUN_FINAL_CAMPAIGN_DRY_RUN}" != "true" ]]; then
    warn "Skipping final campaign dry-run"
    return
  fi

  log "Generating official final campaign evidence in dry-run mode"
  OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run make final-campaign
}

print_summary() {
  local public_host
  public_host="${PUBLIC_HOST}"
  if [[ -z "${public_host}" ]]; then
    public_host="$(curl -fsS --max-time 5 https://ifconfig.me 2>/dev/null || true)"
  fi

  log "SecureRAG Hub cloud demo is ready"
  echo "Local URLs:"
  echo "  API Gateway: http://127.0.0.1:8080/healthz"
  echo "  Portal Web:  http://127.0.0.1:8081/health"
  echo "  Jenkins:     http://127.0.0.1:8085"

  if [[ -n "${public_host}" ]]; then
    echo "Public URLs:"
    echo "  API Gateway: http://${public_host}:8080/healthz"
    echo "  Portal Web:  http://${public_host}:8081/health"
    echo "  Jenkins:     http://${public_host}:8085"
  fi

  echo "Proof pack:"
  find artifacts/support-pack -maxdepth 1 -mindepth 1 -type f -name 'support-demo-*.tar.gz' 2>/dev/null | sort | tail -n 3 || true
}

main() {
  install_base_packages
  ensure_docker_access
  repair_docker_networking
  install_kubectl_if_missing
  install_kind_if_missing
  recreate_cluster_if_requested
  create_cluster_and_secrets
  build_and_push_images
  deploy_demo
  validate_demo
  install_optional_addons
  start_jenkins_if_requested
  run_final_campaign_dry_run
  print_summary
}

main "$@"
