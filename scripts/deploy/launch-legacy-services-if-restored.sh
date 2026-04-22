#!/usr/bin/env bash

set -Eeuo pipefail

ACTION="${1:-start}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SERVICES_DIR="${ROOT_DIR}/services"
RUNTIME_DIR="${ROOT_DIR}/artifacts/legacy-runtime"
LOG_DIR="${RUNTIME_DIR}/logs"
PID_DIR="${RUNTIME_DIR}/pids"
VENV_DIR="${ROOT_DIR}/.venv-legacy"
REPORT_FILE="${RUNTIME_DIR}/legacy-services-launch.md"

ENABLE_LEGACY_SERVICES="${ENABLE_LEGACY_SERVICES:-false}"
INSTALL_REQUIREMENTS="${INSTALL_REQUIREMENTS:-true}"
FORCE_REINSTALL="${FORCE_REINSTALL:-false}"
HOST="${HOST:-127.0.0.1}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

services=(
  "api-gateway"
  "auth-users"
  "chatbot-manager"
  "knowledge-hub"
  "llm-orchestrator"
  "security-auditor"
)

port_for() {
  case "$1" in
    api-gateway) printf '9000' ;;
    auth-users) printf '9001' ;;
    chatbot-manager) printf '9002' ;;
    knowledge-hub) printf '9003' ;;
    llm-orchestrator) printf '9004' ;;
    security-auditor) printf '9005' ;;
    *) return 1 ;;
  esac
}

note_for() {
  case "$1" in
    auth-users|chatbot-manager)
      printf 'legacy Python service superseded by the official Laravel runtime'
      ;;
    *)
      printf 'legacy service excluded from the official Laravel-first runtime until sources are restored'
      ;;
  esac
}

service_dir() {
  printf '%s/%s' "${SERVICES_DIR}" "$1"
}

requirements_file() {
  printf '%s/requirements.txt' "$(service_dir "$1")"
}

entrypoint_file() {
  printf '%s/src/main.py' "$(service_dir "$1")"
}

venv_path() {
  printf '%s/%s' "${VENV_DIR}" "$1"
}

pid_file() {
  printf '%s/%s.pid' "${PID_DIR}" "$1"
}

log_file() {
  printf '%s/%s.log' "${LOG_DIR}" "$1"
}

ensure_dirs() {
  mkdir -p "${LOG_DIR}" "${PID_DIR}" "${VENV_DIR}"
}

row() {
  local service="$1"
  local status="$2"
  local detail="$3"
  local url="$4"
  printf '| %s | %s | %s | %s |\n' "${service}" "${status}" "${detail}" "${url}" >> "${REPORT_FILE}"
}

init_report() {
  mkdir -p "${RUNTIME_DIR}"
  {
    printf '# Legacy Services Local Launcher\n\n'
    printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Action: `%s`\n' "${ACTION}"
    printf -- '- Host: `%s`\n' "${HOST}"
    printf -- '- Official runtime note: `legacy Python services are excluded from the official Laravel-first runtime until sources are intentionally restored`\n\n'
    printf '| Service | Status | Detail | URL |\n'
    printf '|---|---:|---|---|\n'
  } > "${REPORT_FILE}"
}

is_true() {
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

is_running() {
  local service="$1"
  local pid_path
  pid_path="$(pid_file "${service}")"

  [[ -f "${pid_path}" ]] || return 1
  local pid
  pid="$(cat "${pid_path}")"
  [[ -n "${pid}" ]] || return 1
  kill -0 "${pid}" 2>/dev/null
}

health_code() {
  local port="$1"
  local code

  if ! command -v curl >/dev/null 2>&1; then
    printf 'curl-missing'
    return 0
  fi

  code="$(curl -sS -o /dev/null -w '%{http_code}' "http://${HOST}:${port}/healthz" || true)"
  if [[ -z "${code}" || "${code}" == "000" || "${code}" == "404" ]]; then
    code="$(curl -sS -o /dev/null -w '%{http_code}' "http://${HOST}:${port}/health" || true)"
  fi

  printf '%s' "${code:-000}"
}

create_or_refresh_venv() {
  local service="$1"
  local venv
  local req

  venv="$(venv_path "${service}")"
  req="$(requirements_file "${service}")"

  if [[ ! -d "${venv}" ]]; then
    "${PYTHON_BIN}" -m venv "${venv}"
  fi

  if is_true "${FORCE_REINSTALL}"; then
    "${venv}/bin/pip" install --upgrade pip >/dev/null
    "${venv}/bin/pip" install -r "${req}" >/dev/null
    return 0
  fi

  if is_true "${INSTALL_REQUIREMENTS}"; then
    "${venv}/bin/pip" install --upgrade pip >/dev/null
    "${venv}/bin/pip" install -r "${req}" >/dev/null
  fi
}

start_service() {
  local service="$1"
  local port url service_path req entry venv pid_path log_path pid code

  port="$(port_for "${service}")"
  url="http://${HOST}:${port}"
  service_path="$(service_dir "${service}")"
  req="$(requirements_file "${service}")"
  entry="$(entrypoint_file "${service}")"
  venv="$(venv_path "${service}")"
  pid_path="$(pid_file "${service}")"
  log_path="$(log_file "${service}")"

  if [[ ! -d "${service_path}" ]]; then
    row "${service}" "PRÊT_NON_EXÉCUTÉ" "service directory missing" "-"
    return 0
  fi

  if [[ ! -f "${req}" ]]; then
    row "${service}" "PRÊT_NON_EXÉCUTÉ" "requirements.txt missing" "-"
    return 0
  fi

  if [[ ! -f "${entry}" ]]; then
    row "${service}" "PRÊT_NON_EXÉCUTÉ" "src/main.py absent; $(note_for "${service}")" "-"
    return 0
  fi

  if is_running "${service}"; then
    code="$(health_code "${port}")"
    row "${service}" "PARTIEL" "already running (health=${code})" "${url}"
    return 0
  fi

  if ! create_or_refresh_venv "${service}" >>"${log_path}" 2>&1; then
    row "${service}" "PARTIEL" "dependency installation failed; see $(basename "${log_path}")" "-"
    return 0
  fi

  nohup env \
    PORT="${port}" \
    SERVICE_NAME="${service}" \
    "${venv}/bin/python" -m uvicorn src.main:app --host "${HOST}" --port "${port}" \
    >>"${log_path}" 2>&1 &
  pid=$!
  printf '%s\n' "${pid}" > "${pid_path}"
  sleep 2

  if kill -0 "${pid}" 2>/dev/null; then
    code="$(health_code "${port}")"
    row "${service}" "LANCÉ" "process started (health=${code})" "${url}"
  else
    row "${service}" "PARTIEL" "process exited immediately; inspect $(basename "${log_path}")" "${url}"
  fi
}

status_service() {
  local service="$1"
  local port url code pid_path pid detail

  port="$(port_for "${service}")"
  url="http://${HOST}:${port}"
  pid_path="$(pid_file "${service}")"

  if [[ ! -f "$(entrypoint_file "${service}")" ]]; then
    row "${service}" "PRÊT_NON_EXÉCUTÉ" "src/main.py absent; $(note_for "${service}")" "-"
    return 0
  fi

  if is_running "${service}"; then
    pid="$(cat "${pid_path}")"
    code="$(health_code "${port}")"
    detail="pid=${pid}, health=${code}"
    row "${service}" "LANCÉ" "${detail}" "${url}"
  else
    row "${service}" "PARTIEL" "not running" "${url}"
  fi
}

stop_service() {
  local service="$1"
  local pid_path pid

  pid_path="$(pid_file "${service}")"

  if is_running "${service}"; then
    pid="$(cat "${pid_path}")"
    kill "${pid}" 2>/dev/null || true
    sleep 1
    if kill -0 "${pid}" 2>/dev/null; then
      kill -9 "${pid}" 2>/dev/null || true
    fi
    rm -f "${pid_path}"
    row "${service}" "ARRÊTÉ" "process stopped" "-"
  else
    rm -f "${pid_path}"
    row "${service}" "PARTIEL" "no running process found" "-"
  fi
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/deploy/launch-legacy-services-if-restored.sh start
  bash scripts/deploy/launch-legacy-services-if-restored.sh status
  bash scripts/deploy/launch-legacy-services-if-restored.sh stop

Important:
  - This script is for legacy Python services under services/.
  - They are excluded from the official Laravel-first runtime.
  - Services are started only if services/<name>/src/main.py exists.

Environment:
  ENABLE_LEGACY_SERVICES=true   required for start
  INSTALL_REQUIREMENTS=true     install Python requirements into .venv-legacy/<service>
  FORCE_REINSTALL=false         reinstall dependencies even if the venv exists
  HOST=127.0.0.1                bind host for local uvicorn processes
  PYTHON_BIN=python3            Python binary used to create virtual environments
EOF
}

main() {
  ensure_dirs
  init_report

  case "${ACTION}" in
    start)
      if ! is_true "${ENABLE_LEGACY_SERVICES}"; then
        {
          printf '\n## Interpretation\n\n'
          printf -- '- Start refused because ENABLE_LEGACY_SERVICES is not true.\n'
          printf -- '- This is intentional: legacy Python services are not part of the official runtime.\n'
          printf -- '- Set `ENABLE_LEGACY_SERVICES=true` only if you intentionally restored those sources.\n'
        } >> "${REPORT_FILE}"
        printf 'Refusing to start legacy services without ENABLE_LEGACY_SERVICES=true\n' >&2
        printf 'Report written to %s\n' "${REPORT_FILE}"
        exit 1
      fi

      for service in "${services[@]}"; do
        start_service "${service}"
      done
      ;;
    status)
      for service in "${services[@]}"; do
        status_service "${service}"
      done
      ;;
    stop)
      for service in "${services[@]}"; do
        stop_service "${service}"
      done
      ;;
    help|-h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac

  {
    printf '\n## Interpretation\n\n'
    printf -- '- `LANCÉ` means a local uvicorn process is alive for this service.\n'
    printf -- '- `PRÊT_NON_EXÉCUTÉ` means the service source entrypoint is still absent.\n'
    printf -- '- `PARTIEL` means the service exists conceptually but could not be fully started or proved.\n'
    printf -- '- This launcher does not change the official runtime scope of SecureRAG Hub.\n'
  } >> "${REPORT_FILE}"

  printf 'Report written to %s\n' "${REPORT_FILE}"
}

main "$@"
