#!/usr/bin/env bash

set -euo pipefail

# Verify that the official Jenkins CI job has consumed a pushed Git commit.
#
# This script does not trigger Jenkins by itself. It is designed to be run after:
#   git commit --allow-empty -m "ci: validate Jenkins automatic trigger"
#   git push origin main
#
# It polls the Jenkins job API and records whether the expected commit appears
# in the latest build metadata. Authentication is optional but usually required
# when Jenkins security is enabled.

JENKINS_URL="${JENKINS_URL:-http://localhost:8085}"
JENKINS_CI_JOB="${JENKINS_CI_JOB:-securerag-hub-ci}"
GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BRANCH="${GIT_BRANCH:-main}"
EXPECTED_COMMIT="${EXPECTED_COMMIT:-}"
WAIT_SECONDS="${WAIT_SECONDS:-300}"
POLL_SECONDS="${POLL_SECONDS:-10}"
ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts/jenkins}"
OUT_FILE="${OUT_FILE:-${ARTIFACT_DIR}/ci-push-trigger-proof.md}"
RAW_JSON_FILE="${RAW_JSON_FILE:-${ARTIFACT_DIR}/ci-push-last-build.json}"

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

job_api_url() {
  printf '%s/job/%s/lastBuild/api/json?tree=number,result,building,timestamp,duration,url,fullDisplayName,actions[lastBuiltRevision[SHA1,branch[name]],causes[shortDescription,userName]],changeSet[items[commitId,msg,author[fullName]]]' \
    "${JENKINS_URL%/}" "${JENKINS_CI_JOB}"
}

fetch_last_build() {
  local url="$1"
  local output="$2"

  # shellcheck disable=SC2207
  local auth_args=($(curl_auth_args))

  curl -k -sS \
    -o "${output}" \
    -w '%{http_code}' \
    "${auth_args[@]}" \
    "${url}" || printf '000'
}

resolve_expected_commit() {
  if [[ -n "${EXPECTED_COMMIT}" ]]; then
    printf '%s' "${EXPECTED_COMMIT}"
    return 0
  fi

  require_command git
  git rev-parse HEAD
}

remote_head() {
  if ! command -v git >/dev/null 2>&1; then
    printf 'unavailable'
    return 0
  fi

  git ls-remote "${GIT_REMOTE}" "refs/heads/${GIT_BRANCH}" 2>/dev/null | awk '{print $1}' || printf 'unavailable'
}

json_contains_commit() {
  local json_file="$1"
  local commit="$2"
  local short_commit="${commit:0:12}"

  python3 - "${json_file}" "${commit}" "${short_commit}" <<'PY'
import json
import sys

path, full_commit, short_commit = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as handle:
    payload = json.load(handle)

serialized = json.dumps(payload)
if full_commit in serialized or short_commit in serialized:
    print("true")
else:
    print("false")
PY
}

render_build_summary() {
  local json_file="$1"

  python3 - "${json_file}" <<'PY'
import datetime as dt
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)

timestamp = data.get("timestamp")
if isinstance(timestamp, int):
    generated = dt.datetime.fromtimestamp(timestamp / 1000, tz=dt.timezone.utc).isoformat()
else:
    generated = "unknown"

commits = []
for item in (data.get("changeSet") or {}).get("items", []) or []:
    commit = item.get("commitId")
    msg = item.get("msg", "")
    if commit:
        commits.append(f"`{commit}` - {msg}")

revision = "unknown"
for action in data.get("actions", []) or []:
    rev = (action or {}).get("lastBuiltRevision")
    if isinstance(rev, dict) and rev.get("SHA1"):
        revision = rev["SHA1"]
        break

causes = []
for action in data.get("actions", []) or []:
    for cause in (action or {}).get("causes", []) or []:
        desc = cause.get("shortDescription")
        if desc:
            causes.append(desc)

print(f"- Build number: `{data.get('number', 'unknown')}`")
print(f"- Build result: `{data.get('result') or ('BUILDING' if data.get('building') else 'UNKNOWN')}`")
print(f"- Build timestamp UTC: `{generated}`")
print(f"- Build URL: `{data.get('url', 'unknown')}`")
print(f"- Last built revision: `{revision}`")
print(f"- Causes: `{'; '.join(causes) if causes else 'unknown'}`")
print("")
print("### Changeset")
print("")
if commits:
    for commit in commits:
        print(f"- {commit}")
else:
    print("- No changeset entry exposed by Jenkins API.")
PY
}

require_command curl
require_command python3

expected_commit="$(resolve_expected_commit)"
expected_short="${expected_commit:0:12}"
remote_commit="$(remote_head)"
api_url="$(job_api_url)"
deadline=$((SECONDS + WAIT_SECONDS))
match="false"
last_code="000"

{
  printf '# Jenkins CI Push Trigger Proof\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Jenkins URL: `%s`\n' "${JENKINS_URL}"
  printf -- '- CI job: `%s`\n' "${JENKINS_CI_JOB}"
  printf -- '- Expected commit: `%s`\n' "${expected_commit}"
  printf -- '- Expected short commit: `%s`\n' "${expected_short}"
  printf -- '- Remote branch: `%s/%s`\n' "${GIT_REMOTE}" "${GIT_BRANCH}"
  printf -- '- Remote HEAD: `%s`\n\n' "${remote_commit:-unavailable}"
} > "${OUT_FILE}"

info "Waiting up to ${WAIT_SECONDS}s for Jenkins job ${JENKINS_CI_JOB} to expose commit ${expected_short}"

while (( SECONDS <= deadline )); do
  last_code="$(fetch_last_build "${api_url}" "${RAW_JSON_FILE}")"

  case "${last_code}" in
    2*)
      if [[ "$(json_contains_commit "${RAW_JSON_FILE}" "${expected_commit}")" == "true" ]]; then
        match="true"
        break
      fi
      ;;
    403)
      {
        printf '## Status\n\n'
        printf '| Check | Status | Detail |\n'
        printf '|---|---:|---|\n'
        printf '| Jenkins API | PARTIEL | HTTP 403. Provide `JENKINS_USER` and `JENKINS_TOKEN`. |\n'
      } >> "${OUT_FILE}"
      fail "Jenkins API returned 403. Provide JENKINS_USER and JENKINS_TOKEN."
      ;;
    404)
      {
        printf '## Status\n\n'
        printf '| Check | Status | Detail |\n'
        printf '|---|---:|---|\n'
        printf '| Jenkins job | PARTIEL | Job `%s` not found. |\n' "${JENKINS_CI_JOB}"
      } >> "${OUT_FILE}"
      fail "Jenkins job ${JENKINS_CI_JOB} was not found."
      ;;
    *)
      warn "Jenkins API returned HTTP ${last_code}; retrying"
      ;;
  esac

  sleep "${POLL_SECONDS}"
done

{
  printf '## Status\n\n'
  printf '| Check | Status | Detail |\n'
  printf '|---|---:|---|\n'
  if [[ "${match}" == "true" ]]; then
    printf '| Expected commit in Jenkins last build | OK | Commit `%s` found in latest build metadata. |\n' "${expected_short}"
  else
    printf '| Expected commit in Jenkins last build | PARTIEL | Commit `%s` not found before timeout. Last HTTP code: `%s`. |\n' "${expected_short}" "${last_code}"
  fi
  if [[ -n "${remote_commit}" && "${remote_commit}" == "${expected_commit}" ]]; then
    printf '| Git remote HEAD | OK | Remote branch points to expected commit. |\n'
  else
    printf '| Git remote HEAD | WARN | Remote HEAD is `%s`; expected `%s`. |\n' "${remote_commit:-unavailable}" "${expected_commit}"
  fi
  printf '\n## Last Jenkins build summary\n\n'
} >> "${OUT_FILE}"

if [[ -s "${RAW_JSON_FILE}" && "${last_code}" == 2* ]]; then
  render_build_summary "${RAW_JSON_FILE}" >> "${OUT_FILE}"
else
  printf 'No readable Jenkins build JSON was captured.\n' >> "${OUT_FILE}"
fi

{
  printf '\n## Interpretation\n\n'
  printf -- '- `OK` proves Jenkins exposed a build containing the expected pushed commit.\n'
  printf -- '- `PARTIEL` means webhook/polling may still be configured, but this run did not prove commit consumption.\n'
  printf -- '- This proof depends on Jenkins API access and on the CI job retaining SCM metadata.\n'
} >> "${OUT_FILE}"

info "CI push trigger proof written to ${OUT_FILE}"

if [[ "${match}" != "true" ]]; then
  fail "Expected commit ${expected_short} was not found in Jenkins latest build metadata."
fi
