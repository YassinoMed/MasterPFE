#!/usr/bin/env bash

set -euo pipefail

# Improve local stability of the real Ollama mode by pre-pulling the image on
# the host and, if kind already exists, loading it directly into cluster nodes.

CLUSTER_NAME="${CLUSTER_NAME:-securerag-dev}"
OLLAMA_IMAGE="${OLLAMA_IMAGE:-ollama/ollama:0.13.5}"

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

info "Pre-pulling ${OLLAMA_IMAGE} on the host"
docker pull "${OLLAMA_IMAGE}"

if command -v kind >/dev/null 2>&1 && kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  info "Loading ${OLLAMA_IMAGE} into kind cluster ${CLUSTER_NAME}"
  kind load docker-image "${OLLAMA_IMAGE}" --name "${CLUSTER_NAME}"
else
  warn "kind cluster ${CLUSTER_NAME} not found; skipped kind image preload"
fi

info "Ollama preload completed"
