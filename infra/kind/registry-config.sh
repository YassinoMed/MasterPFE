#!/usr/bin/env bash

set -euo pipefail

REG_NAME="${REG_NAME:-kind-registry}"
REG_PORT="${REG_PORT:-5001}"

if ! docker inspect -f '{{.State.Running}}' "${REG_NAME}" >/dev/null 2>&1; then
  docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --name "${REG_NAME}" registry:2
else
  echo "Local registry ${REG_NAME} already running"
fi
