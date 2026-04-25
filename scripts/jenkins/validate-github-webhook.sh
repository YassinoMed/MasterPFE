#!/usr/bin/env bash

set -euo pipefail

# Validate Jenkins live API and GitHub webhook reachability without exposing
# credentials and without blocking the Kubernetes closure when Jenkins is not
# reachable in the current environment.

JENKINS_URL="${JENKINS_URL:-http://127.0.0.1:8085}"
JENKINS_JOB_NAME="${JENKINS_JOB_NAME:-${JENKINS_CI_JOB:-masterpfe-ci}}"
JENKINS_CONTAINER="${JENKINS_CONTAINER:-securerag-jenkins}"
GIT_REMOTE_URL="${GIT_REMOTE_URL:-https://github.com/YassinoMed/MasterPFE.git}"
JOB_DSL_FILE="${JOB_DSL_FILE:-infra/jenkins/jobs/securerag-hub-ci.groovy}"
OUT_FILE="${OUT_FILE:-artifacts/validation/jenkins-webhook-proof.md}"
LEGACY_OUT_FILE="${LEGACY_OUT_FILE:-artifacts/jenkins/github-webhook-validation.md}"
STRICT_JENKINS_PROOF="${STRICT_JENKINS_PROOF:-false}"

mkdir -p "$(dirname "${OUT_FILE}")" "$(dirname "${LEGACY_OUT_FILE}")"

info() { printf '[INFO] %s\n' "$*"; }
is_true() { case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }

auth_args=()
if [[ -n "${JENKINS_USER:-}" && -n "${JENKINS_TOKEN:-}" ]]; then
  auth_args=(-u "${JENKINS_USER}:${JENKINS_TOKEN}")
fi

http_code() {
  local method="$1"
  local url="$2"
  local body_file="$3"
  shift 3
  local code

  if ((${#auth_args[@]} > 0)); then
    code="$(curl --globoff -k -sS \
      -o "${body_file}" \
      -w '%{http_code}' \
      -X "${method}" \
      "${auth_args[@]}" \
      "$@" \
      "${url}" 2>/tmp/securerag-jenkins-curl.err || printf '000')"
  else
    code="$(curl --globoff -k -sS \
      -o "${body_file}" \
      -w '%{http_code}' \
      -X "${method}" \
      "$@" \
      "${url}" 2>/tmp/securerag-jenkins-curl.err || printf '000')"
  fi
  printf '%s' "${code: -3}"
}

api_status() {
  local code="$1"
  case "${code}" in
    2*) printf 'OK' ;;
    401) printf 'DÉPENDANT_DE_L_ENVIRONNEMENT' ;;
    403) printf 'DÉPENDANT_DE_L_ENVIRONNEMENT' ;;
    404) printf 'DÉPENDANT_DE_L_ENVIRONNEMENT' ;;
    000) printf 'DÉPENDANT_DE_L_ENVIRONNEMENT' ;;
    3*|405) printf 'PARTIEL' ;;
    *) printf 'PARTIEL' ;;
  esac
}

diagnostic() {
  local component="$1"
  local code="$2"
  case "${code}" in
    2*) printf '%s reachable: HTTP %s' "${component}" "${code}" ;;
    401) printf 'HTTP 401: Jenkins token absent or invalid; set JENKINS_USER and JENKINS_TOKEN' ;;
    403) printf 'HTTP 403: authenticated user lacks permissions for this Jenkins API path' ;;
    404) printf 'HTTP 404: Jenkins job or endpoint not found; verify JENKINS_JOB_NAME=%s' "${JENKINS_JOB_NAME}" ;;
    000) printf 'HTTP 000: Jenkins unreachable at %s' "${JENKINS_URL}" ;;
    *) printf '%s returned HTTP %s; inspect Jenkins auth, crumb and network settings' "${component}" "${code}" ;;
  esac
}

row() {
  local component="$1"
  local status="$2"
  local detail="$3"
  printf '| %s | %s | %s |\n' "${component}" "${status}" "${detail}" >> "${OUT_FILE}"
}

tmp_root="$(mktemp -d)"
trap 'rm -rf "${tmp_root}"' EXIT

{
  printf '# Jenkins Webhook and API Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `PENDING`\n'
  printf -- '- Jenkins URL: `%s`\n' "${JENKINS_URL}"
  printf -- '- Jenkins job: `%s`\n' "${JENKINS_JOB_NAME}"
  printf -- '- Auth provided: `%s`\n' "$([[ "${#auth_args[@]}" -gt 0 ]] && printf 'yes' || printf 'no')"
  printf -- '- Git remote: `%s`\n\n' "${GIT_REMOTE_URL}"
  printf '| Component | Status | Detail |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

root_body="${tmp_root}/root.json"
root_code="$(http_code GET "${JENKINS_URL%/}/api/json" "${root_body}")"
root_status="$(api_status "${root_code}")"
row "Jenkins root API" "${root_status}" "$(diagnostic 'Root API' "${root_code}")"

job_body="${tmp_root}/job.json"
job_code="$(http_code GET "${JENKINS_URL%/}/job/${JENKINS_JOB_NAME}/api/json?tree=name,buildable,url,lastBuild[number,result,building,timestamp,url],lastCompletedBuild[number,result,timestamp,url]" "${job_body}")"
job_status="$(api_status "${job_code}")"
row "Jenkins job API" "${job_status}" "$(diagnostic 'Job API' "${job_code}")"

last_body="${tmp_root}/last-build.json"
last_code="$(http_code GET "${JENKINS_URL%/}/job/${JENKINS_JOB_NAME}/lastBuild/api/json?tree=number,result,building,timestamp,duration,url,fullDisplayName" "${last_body}")"
last_status="$(api_status "${last_code}")"
row "Jenkins last build API" "${last_status}" "$(diagnostic 'Last build API' "${last_code}")"

webhook_body="${tmp_root}/webhook.txt"
webhook_code="$(
  http_code POST "${JENKINS_URL%/}/github-webhook/" "${webhook_body}" \
    -H 'Content-Type: application/json' \
    -H 'X-GitHub-Event: ping' \
    -H 'X-GitHub-Delivery: securerag-manual-validation' \
    -d '{"zen":"SecureRAG Hub Jenkins webhook validation"}'
)"
webhook_status="$(api_status "${webhook_code}")"
row "GitHub webhook endpoint" "${webhook_status}" "$(diagnostic 'Webhook endpoint' "${webhook_code}")"

if [[ -f "${JOB_DSL_FILE}" ]] && grep -q 'githubPush()' "${JOB_DSL_FILE}"; then
  row "Job DSL trigger" "OK" "\`${JOB_DSL_FILE}\` contains githubPush()"
else
  row "Job DSL trigger" "PARTIEL" "\`${JOB_DSL_FILE}\` does not contain githubPush(); SCM polling may still exist"
fi

if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "${JENKINS_CONTAINER}"; then
  if docker exec "${JENKINS_CONTAINER}" bash -lc "git ls-remote '${GIT_REMOTE_URL}' HEAD >/dev/null" 2>/dev/null; then
    row "Jenkins GitHub egress" "OK" "container \`${JENKINS_CONTAINER}\` can reach GitHub"
  else
    row "Jenkins GitHub egress" "PARTIEL" "container \`${JENKINS_CONTAINER}\` cannot prove GitHub egress"
  fi
else
  row "Jenkins GitHub egress" "DÉPENDANT_DE_L_ENVIRONNEMENT" "container \`${JENKINS_CONTAINER}\` not detected locally"
fi

global_status="TERMINÉ"
if grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*PARTIEL[[:space:]]*[|]' "${OUT_FILE}"; then
  global_status="PARTIEL"
fi
if grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*DÉPENDANT_DE_L_ENVIRONNEMENT[[:space:]]*[|]' "${OUT_FILE}"; then
  global_status="DÉPENDANT_DE_L_ENVIRONNEMENT"
fi

{
  printf '\n## Last build summary\n\n'
  if [[ -s "${last_body}" && "${last_code}" == 2* ]]; then
    python3 - "${last_body}" <<'PY' 2>/dev/null || true
import datetime as dt
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)

timestamp = data.get("timestamp")
if isinstance(timestamp, int):
    when = dt.datetime.fromtimestamp(timestamp / 1000, tz=dt.timezone.utc).isoformat()
else:
    when = "unknown"

result = data.get("result") or ("BUILDING" if data.get("building") else "UNKNOWN")
print(f"- Build number: `{data.get('number', 'unknown')}`")
print(f"- Build result: `{result}`")
print(f"- Build timestamp UTC: `{when}`")
print(f"- Build URL: `{data.get('url', 'unknown')}`")
PY
  else
    printf 'No readable last build JSON was captured.\n'
  fi

  printf '\n## Interpretation\n\n'
  printf -- '- `TERMINÉ` proves the Jenkins API and webhook endpoint are reachable for the configured job.\n'
  printf -- '- `DÉPENDANT_DE_L_ENVIRONNEMENT` is expected when Jenkins is stopped, the API token is absent/invalid, permissions are insufficient, or `JENKINS_JOB_NAME` does not match the real job.\n'
  printf -- '- This report never writes the Jenkins token or password.\n'
} >> "${OUT_FILE}"

python3 - "${OUT_FILE}" "${global_status}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
status = sys.argv[2]
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("- Status: `PENDING`", f"- Status: `{status}`", 1), encoding="utf-8")
PY

cp "${OUT_FILE}" "${LEGACY_OUT_FILE}"
info "Jenkins webhook/API proof written to ${OUT_FILE}"

if is_true "${STRICT_JENKINS_PROOF}" && [[ "${global_status}" != "TERMINÉ" ]]; then
  exit 1
fi
