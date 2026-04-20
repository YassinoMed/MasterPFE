#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/YassinoMed/MasterPFE.git}"
APP_DIR="${APP_DIR:-/MasterPFE}"
BRANCH="${BRANCH:-main}"
RUN_STACK="${RUN_STACK:-true}"

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

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return
  fi

  command -v apt-get >/dev/null 2>&1 || fail "git is missing and apt-get is not available"
  log "Installing git and CA certificates"
  as_root apt-get update
  as_root apt-get install -y ca-certificates git
}

clone_or_update_repo() {
  if [[ -d "${APP_DIR}/.git" ]]; then
    log "Repository already exists at ${APP_DIR}; updating branch ${BRANCH} with fast-forward only"
    git -C "${APP_DIR}" fetch origin "${BRANCH}"
    git -C "${APP_DIR}" checkout "${BRANCH}"
    git -C "${APP_DIR}" pull --ff-only origin "${BRANCH}"
    return
  fi

  if [[ -e "${APP_DIR}" ]]; then
    fail "${APP_DIR} exists but is not a Git repository. Move it or set APP_DIR to another path."
  fi

  log "Cloning ${REPO_URL} into ${APP_DIR}"
  git clone --branch "${BRANCH}" "${REPO_URL}" "${APP_DIR}"
}

run_stack_if_requested() {
  if [[ "${RUN_STACK}" != "true" ]]; then
    warn "RUN_STACK=${RUN_STACK}; repository is ready but deployment was not started."
    return
  fi

  log "Starting Debian 12 cloud deployment from ${APP_DIR}"
  cd "${APP_DIR}"
  bash scripts/deploy/cloud-debian12-full-run.sh
}

main() {
  ensure_git
  clone_or_update_repo
  run_stack_if_requested
}

main "$@"
