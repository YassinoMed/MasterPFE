#!/usr/bin/env bash

set -euo pipefail

# Validate the Jenkins <-> GitHub push automation path without changing jobs.
#
# This script is intentionally conservative:
# - It checks that Jenkins is reachable.
# - It sends a harmless GitHub "ping" style POST to /github-webhook/.
# - It verifies that the local Job DSL contains the GitHub push trigger.
# - It optionally checks the Jenkins job API when credentials are provided.
# - It checks GitHub egress from the Jenkins container when Docker is available.

JENKINS_URL="${JENKINS_URL:-http://localhost:8085}"
JENKINS_CI_JOB="${JENKINS_CI_JOB:-securerag-hub-ci}"
JENKINS_CONTAINER="${JENKINS_CONTAINER:-securerag-jenkins}"
GIT_REMOTE_URL="${GIT_REMOTE_URL:-https://github.com/YassinoMed/MasterPFE.git}"
JOB_DSL_FILE="${JOB_DSL_FILE:-infra/jenkins/jobs/securerag-hub-ci.groovy}"
ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts/jenkins}"
OUT_FILE="${OUT_FILE:-${ARTIFACT_DIR}/github-webhook-validation.md}"

mkdir -p "${ARTIFACT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

curl_auth_args() {
  if [[ -n "${JENKINS_USER:-}" && -n "${JENKINS_TOKEN:-}" ]]; then
    printf '%s\n' "-u" "${JENKINS_USER}:${JENKINS_TOKEN}"
  fi
}

http_code() {
  local method="$1"
  local url="$2"
  shift 2

  # shellcheck disable=SC2207
  local auth_args=($(curl_auth_args))

  curl -k -sS -o /tmp/securerag-webhook-check-body.txt \
    -w '%{http_code}' \
    -X "${method}" \
    "${auth_args[@]}" \
    "$@" \
    "${url}" || printf '000'
}

status_label() {
  local code="$1"

  case "${code}" in
    2*) printf 'OK' ;;
    3*) printf 'WARN' ;;
    403|405) printf 'WARN' ;;
    *) printf 'FAIL' ;;
  esac
}

record() {
  local component="$1"
  local status="$2"
  local detail="$3"

  printf '| %s | %s | %s |\n' "${component}" "${status}" "${detail}" >> "${OUT_FILE}"
}

require_command curl

{
  printf '# Jenkins GitHub Webhook Validation\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Jenkins URL: `%s`\n' "${JENKINS_URL}"
  printf -- '- CI job: `%s`\n' "${JENKINS_CI_JOB}"
  printf -- '- Git remote: `%s`\n\n' "${GIT_REMOTE_URL}"
  printf '| Component | Status | Detail |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

login_code="$(http_code GET "${JENKINS_URL%/}/login")"
case "${login_code}" in
  2*|3*|403)
    info "Jenkins is reachable: HTTP ${login_code}"
    record "Jenkins login" "OK" "HTTP ${login_code}"
    ;;
  *)
    record "Jenkins login" "FAIL" "HTTP ${login_code}"
    fail "Jenkins is not reachable at ${JENKINS_URL}"
    ;;
esac

webhook_code="$(
  http_code POST "${JENKINS_URL%/}/github-webhook/" \
    -H 'Content-Type: application/json' \
    -H 'X-GitHub-Event: ping' \
    -H 'X-GitHub-Delivery: securerag-manual-validation' \
    -d '{"zen":"SecureRAG Hub Jenkins webhook validation"}'
)"
webhook_status="$(status_label "${webhook_code}")"
record "Webhook endpoint" "${webhook_status}" "POST /github-webhook/ returned HTTP ${webhook_code}"

if [[ "${webhook_status}" == "FAIL" ]]; then
  fail "Webhook endpoint did not look reachable: HTTP ${webhook_code}"
fi

if [[ -f "${JOB_DSL_FILE}" ]] && grep -q 'githubPush()' "${JOB_DSL_FILE}"; then
  record "Job DSL trigger" "OK" "${JOB_DSL_FILE} contains githubPush()"
else
  record "Job DSL trigger" "FAIL" "${JOB_DSL_FILE} does not contain githubPush()"
  fail "CI Job DSL is missing githubPush()"
fi

job_api_url="${JENKINS_URL%/}/job/${JENKINS_CI_JOB}/api/json?tree=name,buildable,lastBuild[number,result,timestamp],lastCompletedBuild[number,result,timestamp]"
job_code="$(http_code GET "${job_api_url}")"
case "${job_code}" in
  2*)
    record "Jenkins CI job API" "OK" "Job API reachable with HTTP ${job_code}"
    ;;
  403)
    record "Jenkins CI job API" "WARN" "HTTP 403; provide JENKINS_USER and JENKINS_TOKEN for authenticated validation"
    ;;
  404)
    record "Jenkins CI job API" "FAIL" "Job ${JENKINS_CI_JOB} not found"
    fail "Jenkins job ${JENKINS_CI_JOB} was not found"
    ;;
  *)
    record "Jenkins CI job API" "WARN" "HTTP ${job_code}; inspect Jenkins auth/network settings"
    ;;
esac

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -qx "${JENKINS_CONTAINER}"; then
  if docker exec "${JENKINS_CONTAINER}" bash -lc "git ls-remote '${GIT_REMOTE_URL}' HEAD >/dev/null"; then
    record "Jenkins GitHub egress" "OK" "Container ${JENKINS_CONTAINER} can reach GitHub"
  else
    record "Jenkins GitHub egress" "WARN" "Webhook may work, but SCM checkout can fail from ${JENKINS_CONTAINER}"
    warn "Jenkins container cannot reach GitHub reliably; keep /workspace fallback ready"
  fi
else
  record "Jenkins GitHub egress" "WARN" "Docker container ${JENKINS_CONTAINER} not detected locally"
fi

{
  printf '\n## Interpretation\n\n'
  printf -- '- `405 Method Not Allowed` for `curl -I` is normal because Jenkins expects a POST webhook.\n'
  printf -- '- The definitive GitHub-side proof is the `Recent Deliveries` page showing a successful delivery.\n'
  printf -- '- If webhook delivery succeeds but checkout fails, the remaining issue is Jenkins container egress to GitHub.\n'
} >> "${OUT_FILE}"

info "Webhook validation written to ${OUT_FILE}"
