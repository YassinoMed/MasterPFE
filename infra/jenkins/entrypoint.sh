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

exec /usr/bin/tini -- /usr/local/bin/jenkins.sh
