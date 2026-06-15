#!/usr/bin/env bash

set -euo pipefail

INFO="[INFO]"
ERROR="[ERROR]"

SONAR_DIR="infra/sonarqube"
COMPOSE_FILE="${SONAR_DIR}/docker-compose.sonarqube.yml"

echo "${INFO} Checking Docker daemon..."
command -v docker >/dev/null 2>&1 || { echo "${ERROR} Docker is not installed or not in PATH."; exit 1; }
docker info >/dev/null 2>&1 || { echo "${ERROR} Docker daemon is not running."; exit 1; }

echo "${INFO} Preparing environment..."
if [[ ! -f "${SONAR_DIR}/.env" ]]; then
  if [[ -f "${SONAR_DIR}/.env.example" ]]; then
    cp "${SONAR_DIR}/.env.example" "${SONAR_DIR}/.env"
    echo "${INFO} Created .env from .env.example"
  fi
fi

# Required by SonarQube Elasticsearch
if [[ "$(uname)" == "Darwin" ]]; then
  echo "${INFO} Mac OS detected: Ensure Docker Desktop VM has at least 2GB RAM."
elif [[ "$(uname)" == "Linux" ]]; then
  echo "${INFO} Setting vm.max_map_count for Elasticsearch..."
  sudo sysctl -w vm.max_map_count=262144
fi

echo "${INFO} Starting SonarQube infrastructure..."
docker compose -f "${COMPOSE_FILE}" --env-file "${SONAR_DIR}/.env" up -d

echo "${INFO} SonarQube is starting up. This may take a minute or two."
echo "${INFO} You can access it at http://localhost:9000 (Default credentials: admin / admin)"
echo "${INFO} To view logs, run: docker compose -f ${COMPOSE_FILE} logs -f"
