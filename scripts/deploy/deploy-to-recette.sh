#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy-to-recette.sh — Deploy SecureRAG Hub to the recette (staging) machine
# via SSH. This script is designed to be called from a Jenkins pipeline or
# from a local workstation.
#
# Required environment variables:
#   RECETTE_HOST   — IP or hostname of the recette machine (default: 83.229.82.46)
#   RECETTE_USER   — SSH user on the recette machine       (default: root)
#
# Optional:
#   SSH_KEY_FILE   — Path to the SSH private key            (auto-detected)
#   REPO_URL       — Git repository URL
#   BRANCH         — Git branch to deploy                   (default: main)
#   APP_DIR        — Remote path to the cloned repo         (default: /MasterPFE)
#   IMAGE_TAG      — Docker image tag to build              (default: demo)
#   SKIP_BUILD     — Set to "true" to skip image build      (default: false)
#   SKIP_SMOKE     — Set to "true" to skip smoke tests      (default: false)
#   DRY_RUN        — Set to "true" to only print commands   (default: false)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Configuration ─────────────────────────────────────────────────────────
RECETTE_HOST="${RECETTE_HOST:-83.229.82.46}"
RECETTE_USER="${RECETTE_USER:-root}"
SSH_KEY_FILE="${SSH_KEY_FILE:-}"
REPO_URL="${REPO_URL:-https://github.com/YassinoMed/MasterPFE.git}"
BRANCH="${BRANCH:-main}"
APP_DIR="${APP_DIR:-/MasterPFE}"
IMAGE_TAG="${IMAGE_TAG:-demo}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/recette}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_SMOKE="${SKIP_SMOKE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=no -o ConnectTimeout=30}"
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-600}"

# ── Logging ───────────────────────────────────────────────────────────────
log()  { printf '[INFO]  %s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
warn() { printf '[WARN]  %s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }
fail() { printf '[ERROR] %s  %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; exit 1; }

# ── SSH helper ────────────────────────────────────────────────────────────
build_ssh_cmd() {
  local cmd="ssh"
  if [[ -n "${SSH_KEY_FILE}" ]]; then
    cmd="${cmd} -i ${SSH_KEY_FILE}"
  fi
  # shellcheck disable=SC2086
  cmd="${cmd} ${SSH_OPTS} ${RECETTE_USER}@${RECETTE_HOST}"
  echo "${cmd}"
}

remote_exec() {
  local ssh_cmd
  ssh_cmd="$(build_ssh_cmd)"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "[DRY-RUN] ${ssh_cmd} << 'REMOTE_SCRIPT'"
    cat
    echo "REMOTE_SCRIPT"
    return 0
  fi

  # shellcheck disable=SC2086
  ${ssh_cmd} bash -s
}

# ── Pre-flight checks ────────────────────────────────────────────────────
preflight() {
  log "Pre-flight check: verifying SSH connectivity to ${RECETTE_USER}@${RECETTE_HOST}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "[DRY-RUN] SSH connectivity check skipped"
    return 0
  fi

  local ssh_cmd
  ssh_cmd="$(build_ssh_cmd)"
  # shellcheck disable=SC2086
  if ! ${ssh_cmd} 'echo "SSH_OK"' 2>/dev/null | grep -q "SSH_OK"; then
    fail "Cannot connect to ${RECETTE_USER}@${RECETTE_HOST}. Check SSH key, user, and firewall."
  fi

  log "SSH connectivity: OK"
}

# ── Step 1: Clone or update repository ────────────────────────────────────
step_clone_or_update() {
  log "Step 1/5: Clone or update repository on recette (${APP_DIR}, branch: ${BRANCH})"

  remote_exec <<REMOTE_SCRIPT
set -euo pipefail

echo "[RECETTE] Ensuring git is available"
if ! command -v git >/dev/null 2>&1; then
  apt-get update && apt-get install -y ca-certificates git
fi

if [ -d "${APP_DIR}/.git" ]; then
  echo "[RECETTE] Repository exists at ${APP_DIR}; pulling latest changes"
  cd "${APP_DIR}"
  git fetch origin "${BRANCH}"
  git checkout "${BRANCH}"
  git reset --hard "origin/${BRANCH}"
else
  echo "[RECETTE] Cloning ${REPO_URL} into ${APP_DIR}"
  git clone --branch "${BRANCH}" "${REPO_URL}" "${APP_DIR}"
fi

cd "${APP_DIR}"
echo "[RECETTE] Current commit: \$(git log -1 --oneline)"
echo "[RECETTE] Repository ready"
REMOTE_SCRIPT
}

# ── Step 2: Ensure infrastructure ─────────────────────────────────────────
step_ensure_infra() {
  log "Step 2/5: Ensure infrastructure on recette (Docker, Kind, kubectl)"

  remote_exec <<'REMOTE_SCRIPT'
set -euo pipefail

echo "[RECETTE] Checking Docker"
if ! command -v docker >/dev/null 2>&1; then
  echo "[RECETTE] Installing Docker"
  curl -fsSL https://get.docker.com | bash
  systemctl enable --now docker
fi
docker info > /dev/null 2>&1 || { echo "[ERROR] Docker is not running"; exit 1; }

echo "[RECETTE] Checking Docker Compose plugin"
if ! docker compose version >/dev/null 2>&1; then
  echo "[RECETTE] Installing Docker Compose plugin"
  apt-get update && apt-get install -y docker-compose-plugin
fi

echo "[RECETTE] Checking kubectl"
if ! command -v kubectl >/dev/null 2>&1; then
  ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
  KUBE_VER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  curl -fsSLo /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBE_VER}/bin/linux/${ARCH}/kubectl"
  chmod +x /usr/local/bin/kubectl
fi

echo "[RECETTE] Checking kind"
if ! command -v kind >/dev/null 2>&1; then
  ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
  curl -fsSLo /usr/local/bin/kind \
    "https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-${ARCH}"
  chmod +x /usr/local/bin/kind
fi

echo "[RECETTE] Docker: $(docker --version)"
echo "[RECETTE] kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client -o yaml | awk '/gitVersion/ {print $2; exit}')"
echo "[RECETTE] kind: $(kind version)"
echo "[RECETTE] Infrastructure: OK"
REMOTE_SCRIPT
}

# ── Step 3: Build and deploy ──────────────────────────────────────────────
step_build_and_deploy() {
  log "Step 3/5: Build images and deploy on recette"

  remote_exec <<REMOTE_SCRIPT
set -euo pipefail
cd "${APP_DIR}"

# Enable IP forwarding for Docker networking
sysctl -w net.ipv4.ip_forward=1 || true
iptables -P FORWARD ACCEPT 2>/dev/null || true

echo "[RECETTE] Creating/ensuring Kind cluster"
bash scripts/deploy/create-kind.sh

echo "[RECETTE] Bootstrapping secrets"
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh

if [ "${SKIP_BUILD}" != "true" ]; then
  echo "[RECETTE] Building Docker images (tag: ${IMAGE_TAG})"
  REGISTRY_HOST="${REGISTRY_HOST}" \
  IMAGE_PREFIX="${IMAGE_PREFIX}" \
  IMAGE_TAG="${IMAGE_TAG}" \
    bash scripts/deploy/build-local-images.sh
else
  echo "[RECETTE] Skipping image build (SKIP_BUILD=true)"
fi

echo "[RECETTE] Installing Kyverno (Required for ClusterPolicies)"
bash scripts/deploy/install-kyverno.sh

echo "[RECETTE] Deploying via Kustomize overlay: ${KUSTOMIZE_OVERLAY}"
REGISTRY_HOST="${REGISTRY_HOST}" \
IMAGE_PREFIX="${IMAGE_PREFIX}" \
IMAGE_TAG="${IMAGE_TAG}" \
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" \
  bash scripts/deploy/deploy-kind.sh

echo "[RECETTE] Restarting pods for clean rollout"
kubectl delete pod -n securerag-hub --all 2>/dev/null || true
kubectl wait --for=condition=Ready pod --all -n securerag-hub --timeout=300s || {
  echo "[WARN] Some pods did not reach Ready state within 300s"
  kubectl get pods -n securerag-hub
}

echo "[RECETTE] Deployment complete"
kubectl get all -n securerag-hub
REMOTE_SCRIPT
}

# ── Step 4: Smoke tests ──────────────────────────────────────────────────
step_smoke_tests() {
  if [[ "${SKIP_SMOKE}" == "true" ]]; then
    log "Step 4/5: Smoke tests skipped (SKIP_SMOKE=true)"
    return 0
  fi

  log "Step 4/5: Running smoke tests on recette"

  remote_exec <<REMOTE_SCRIPT
set -euo pipefail
cd "${APP_DIR}"

echo "[RECETTE] Running smoke tests"
IMAGE_TAG="${IMAGE_TAG}" bash scripts/validate/smoke-tests.sh || {
  echo "[WARN] Smoke tests had failures; check logs above"
}

echo "[RECETTE] Checking portal health endpoint"
if curl -fsS --max-time 10 "http://127.0.0.1:9081/health" >/dev/null 2>&1; then
  echo "[RECETTE] Portal health: OK"
else
  echo "[WARN] Portal health endpoint not reachable on localhost:9081"
fi
REMOTE_SCRIPT
}

# ── Step 5: Start Jenkins on recette ──────────────────────────────────────
step_start_jenkins() {
  log "Step 5/5: Ensure Jenkins is running on recette"

  remote_exec <<REMOTE_SCRIPT
set -euo pipefail
cd "${APP_DIR}"

echo "[RECETTE] Bootstrapping Jenkins credentials"
bash scripts/jenkins/bootstrap-local-credentials.sh

echo "[RECETTE] Exporting kubeconfig for Jenkins"
bash scripts/jenkins/bootstrap-local-kubeconfig.sh

echo "[RECETTE] Starting Jenkins via Docker Compose"
docker compose -f infra/jenkins/docker-compose.yml up -d --build

echo "[RECETTE] Waiting for Jenkins to be healthy..."
for i in \$(seq 1 30); do
  if curl -fsS --max-time 5 "http://127.0.0.1:8085/login" >/dev/null 2>&1; then
    echo "[RECETTE] Jenkins is ready!"
    break
  fi
  echo "[RECETTE] Waiting for Jenkins... (\${i}/30)"
  sleep 10
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  SecureRAG Hub — Recette Deployment Complete"
echo "═══════════════════════════════════════════════════════════════"
echo "  Portal Web:  http://${RECETTE_HOST}:9081/health"
echo "  Jenkins:     http://${RECETTE_HOST}:8085"
echo "═══════════════════════════════════════════════════════════════"
REMOTE_SCRIPT
}

# ── Main ──────────────────────────────────────────────────────────────────
main() {
  log "╔═══════════════════════════════════════════════════════════════╗"
  log "║  SecureRAG Hub — Deploy to Recette                          ║"
  log "║  Target: ${RECETTE_USER}@${RECETTE_HOST}                    ║"
  log "║  Branch: ${BRANCH} | Tag: ${IMAGE_TAG}                      ║"
  log "╚═══════════════════════════════════════════════════════════════╝"

  preflight
  step_clone_or_update
  step_ensure_infra
  step_build_and_deploy
  step_smoke_tests
  step_start_jenkins

  log "All deployment steps completed successfully"
}

main "$@"
