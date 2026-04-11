#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

CLUSTER_NAME="${CLUSTER_NAME:-securerag-dev}"
CONTROL_PLANE_NAME="${CONTROL_PLANE_NAME:-${CLUSTER_NAME}-control-plane}"
JENKINS_CONTAINER="${JENKINS_CONTAINER:-securerag-jenkins}"
JENKINS_COMPOSE_FILE="${JENKINS_COMPOSE_FILE:-infra/jenkins/docker-compose.yml}"
KUBECONFIG_OUTPUT="${KUBECONFIG_OUTPUT:-infra/jenkins/secrets/kubeconfig}"
KUBERNETES_NAMESPACE="${KUBERNETES_NAMESPACE:-securerag-hub}"

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

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

ensure_prerequisites() {
  require_command docker
  require_command kind
  require_command kubectl
  require_command sed
  require_command grep

  docker ps --format '{{.Names}}' | grep -qx "${JENKINS_CONTAINER}" || fail "Container ${JENKINS_CONTAINER} is not running"
  kind get clusters | grep -qx "${CLUSTER_NAME}" || fail "kind cluster ${CLUSTER_NAME} does not exist"
  docker network inspect kind >/dev/null 2>&1 || fail "Docker network kind does not exist"
}

connect_jenkins_to_kind_network() {
  log "Connecting ${JENKINS_CONTAINER} to Docker network kind"
  docker network connect kind "${JENKINS_CONTAINER}" 2>/dev/null || true
}

verify_apiserver_network() {
  log "Checking Kubernetes API reachability from Jenkins"
  docker exec "${JENKINS_CONTAINER}" bash -lc \
    "curl -kfsS https://${CONTROL_PLANE_NAME}:6443/livez?verbose >/tmp/k8s-livez.txt && tail -n 1 /tmp/k8s-livez.txt"
}

write_jenkins_kubeconfig() {
  log "Exporting kubeconfig for Jenkins"
  mkdir -p "$(dirname "${KUBECONFIG_OUTPUT}")"
  kind export kubeconfig --name "${CLUSTER_NAME}" --kubeconfig /tmp/kubeconfig-jenkins
  sed -i "s#server: https://.*:6443#server: https://${CONTROL_PLANE_NAME}:6443#g" /tmp/kubeconfig-jenkins
  cp /tmp/kubeconfig-jenkins "${KUBECONFIG_OUTPUT}"
  chmod 600 "${KUBECONFIG_OUTPUT}"

  log "Kubeconfig summary"
  grep -n "server:\|current-context" "${KUBECONFIG_OUTPUT}"
}

restart_jenkins() {
  log "Restarting Jenkins to reload mounted kubeconfig"
  docker compose -f "${JENKINS_COMPOSE_FILE}" restart jenkins

  log "Waiting for Jenkins"
  for _ in $(seq 1 60); do
    if curl -fsS http://127.0.0.1:8085/login >/dev/null; then
      log "Jenkins is reachable"
      return
    fi
    sleep 5
  done

  fail "Jenkins did not become reachable on http://127.0.0.1:8085"
}

verify_kubectl_from_jenkins() {
  log "Reconnecting ${JENKINS_CONTAINER} to kind network after restart"
  docker network connect kind "${JENKINS_CONTAINER}" 2>/dev/null || true

  log "Validating kubectl from Jenkins"
  docker exec "${JENKINS_CONTAINER}" bash -lc \
    "KUBECONFIG=/var/jenkins_home/.kube/config kubectl config current-context"
  docker exec "${JENKINS_CONTAINER}" bash -lc \
    "KUBECONFIG=/var/jenkins_home/.kube/config kubectl get pods -n ${KUBERNETES_NAMESPACE}"
}

print_next_steps() {
  cat <<EOF

[OK] Jenkins can now reach the kind cluster.

Use this environment variable in local Jenkins pipeline scripts:

  KUBECONFIG=/var/jenkins_home/.kube/config

Recommended Jenkins CD parameters:

  OFFICIAL_SCENARIO=demo
  CAMPAIGN_MODE=dry-run

EOF
}

main() {
  ensure_prerequisites
  connect_jenkins_to_kind_network
  verify_apiserver_network
  write_jenkins_kubeconfig
  restart_jenkins
  verify_kubectl_from_jenkins
  print_next_steps
}

main "$@"
