#!/usr/bin/env bash

set -euo pipefail

start_forwarder() {
  local listen_port="$1"
  local target_port="$2"

  if [[ "${ENABLE_LOCAL_FORWARDING:-true}" != "true" ]]; then
    return 0
  fi

  if ! command -v socat >/dev/null 2>&1; then
    echo "[WARN] socat is not installed; skipping localhost:${listen_port} forwarder" >&2
    return 0
  fi

  socat "TCP-LISTEN:${listen_port},bind=127.0.0.1,reuseaddr,fork" "TCP:host.docker.internal:${target_port}" &
}

# Forward localhost endpoints expected by the repository scripts so the
# containerized Jenkins instance can reach the host kind cluster and registry.
start_forwarder 5001 5001
start_forwarder 6443 6443

if [[ -z "${JENKINS_ADMIN_PASSWORD:-}" && -n "${JENKINS_ADMIN_PASSWORD_FILE:-}" ]]; then
  if [[ ! -r "${JENKINS_ADMIN_PASSWORD_FILE}" ]]; then
    echo "[ERROR] JENKINS_ADMIN_PASSWORD_FILE is not readable: ${JENKINS_ADMIN_PASSWORD_FILE}" >&2
    exit 1
  fi

  JENKINS_ADMIN_PASSWORD="$(tr -d '\r\n' < "${JENKINS_ADMIN_PASSWORD_FILE}")"
  export JENKINS_ADMIN_PASSWORD
fi

if [[ -z "${JENKINS_ADMIN_PASSWORD:-}" || "${JENKINS_ADMIN_PASSWORD}" == "change-me-now" || "${JENKINS_ADMIN_PASSWORD}" == "change-me" ]]; then
  echo "[ERROR] Jenkins admin password is missing or still a placeholder." >&2
  echo "[ERROR] Run scripts/jenkins/bootstrap-local-credentials.sh before starting Jenkins." >&2
  exit 1
fi

exec /usr/bin/tini -- /usr/local/bin/jenkins.sh
