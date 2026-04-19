#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

CLUSTER_NAME="${CLUSTER_NAME:-securerag-prod}"
KIND_CONFIG="${KIND_CONFIG:-infra/kind/kind-production.yaml}"
REG_NAME="${REG_NAME:-kind-registry}"
REG_PORT="${REG_PORT:-5001}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-240s}"
CONFIRM_DESTROY="${CONFIRM_DESTROY:-NO}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

require_command docker
require_command kind
require_command kubectl

if ! docker info >/dev/null 2>&1; then
  error "Docker is not reachable. Start Docker Desktop or the Docker daemon first."
  exit 2
fi

if [[ ! -f "${KIND_CONFIG}" ]]; then
  error "kind production config not found: ${KIND_CONFIG}"
  exit 2
fi

info "Ensuring local registry ${REG_NAME} is running on 127.0.0.1:${REG_PORT}"
REG_NAME="${REG_NAME}" REG_PORT="${REG_PORT}" bash infra/kind/registry-config.sh

if kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
  warn "Cluster ${CLUSTER_NAME} already exists."
  warn "Recreating it is destructive for all workloads, local volumes and runtime evidence in that cluster."
  if [[ "${CONFIRM_DESTROY}" != "YES" ]]; then
    warn "Refusing to delete cluster. Rerun with CONFIRM_DESTROY=YES when this is intentional."
    exit 1
  fi
  info "Deleting existing kind cluster ${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}"
fi

info "Creating production-like kind cluster ${CLUSTER_NAME} from ${KIND_CONFIG}"
kind create cluster --config "${KIND_CONFIG}"

if docker network inspect kind >/dev/null 2>&1; then
  if ! docker network inspect kind --format '{{json .Containers}}' | grep -q "\"${REG_NAME}\""; then
    info "Connecting ${REG_NAME} to kind network"
    docker network connect kind "${REG_NAME}" || true
  fi
fi

info "Configuring localhost:${REG_PORT} registry mirror in kind nodes"
for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
  docker exec "${node}" mkdir -p "/etc/containerd/certs.d/localhost:${REG_PORT}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "/etc/containerd/certs.d/localhost:${REG_PORT}/hosts.toml"
[host."http://${REG_NAME}:5000"]
EOF
done

kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

info "Waiting for all production-like kind nodes to become Ready"
kubectl wait --for=condition=Ready nodes --all --timeout="${WAIT_TIMEOUT}"
kubectl get nodes -o wide

cat <<EOF

[INFO] Production-like cluster is ready.
[INFO] Context: kind-${CLUSTER_NAME}
[INFO] Local registry: localhost:${REG_PORT}
[INFO] Portal NodePort mapping expected after deployment: http://localhost:8081/health
EOF
