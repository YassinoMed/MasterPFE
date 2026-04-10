#!/usr/bin/env bash

set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8085}"
JENKINS_TIMEOUT_SECONDS="${JENKINS_TIMEOUT_SECONDS:-300}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

deadline=$(( $(date +%s) + JENKINS_TIMEOUT_SECONDS ))

until curl -fsS "${JENKINS_URL}/login" >/dev/null 2>&1; do
  if (( $(date +%s) >= deadline )); then
    error "Timed out while waiting for Jenkins at ${JENKINS_URL}"
    exit 1
  fi
  info "Waiting for Jenkins at ${JENKINS_URL}..."
  sleep 5
done

info "Jenkins is reachable at ${JENKINS_URL}"
