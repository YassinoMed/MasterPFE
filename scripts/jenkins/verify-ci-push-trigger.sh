#!/usr/bin/env bash

set -euo pipefail

# Prove that Jenkins can expose the latest CI build and, when possible, that
# the expected Git commit appears in the build metadata. Jenkins failures are
# classified honestly but do not fail the Kubernetes closure by default.

JENKINS_URL="${JENKINS_URL:-http://127.0.0.1:8085}"
JENKINS_JOB_NAME="${JENKINS_JOB_NAME:-${JENKINS_CI_JOB:-masterpfe-ci}}"
GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BRANCH="${GIT_BRANCH:-main}"
EXPECTED_COMMIT="${EXPECTED_COMMIT:-}"
WAIT_SECONDS="${WAIT_SECONDS:-0}"
POLL_SECONDS="${POLL_SECONDS:-10}"
OUT_FILE="${OUT_FILE:-artifacts/validation/jenkins-ci-push-proof.md}"
LEGACY_OUT_FILE="${LEGACY_OUT_FILE:-artifacts/jenkins/ci-push-trigger-proof.md}"
RAW_JSON_FILE="${RAW_JSON_FILE:-artifacts/validation/jenkins-ci-last-build.json}"
STRICT_JENKINS_PROOF="${STRICT_JENKINS_PROOF:-false}"

mkdir -p "$(dirname "${OUT_FILE}")" "$(dirname "${LEGACY_OUT_FILE}")" "$(dirname "${RAW_JSON_FILE}")"

info() { printf '[INFO] %s\n' "$*"; }
is_true() { case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }

auth_args=()
if [[ -n "${JENKINS_USER:-}" && -n "${JENKINS_TOKEN:-}" ]]; then
  auth_args=(-u "${JENKINS_USER}:${JENKINS_TOKEN}")
fi

resolve_expected_commit() {
  if [[ -n "${EXPECTED_COMMIT}" ]]; then
    printf '%s' "${EXPECTED_COMMIT}"
  elif command -v git >/dev/null 2>&1; then
    git rev-parse HEAD 2>/dev/null || printf 'unknown'
  else
    printf 'unknown'
  fi
}

remote_head() {
  if command -v git >/dev/null 2>&1; then
    git ls-remote "${GIT_REMOTE}" "refs/heads/${GIT_BRANCH}" 2>/dev/null | awk '{print $1}' || printf 'unavailable'
  else
    printf 'unavailable'
  fi
}

http_code() {
  local url="$1"
  local output="$2"
  local code
  if ((${#auth_args[@]} > 0)); then
    code="$(curl --globoff -k -sS \
      -o "${output}" \
      -w '%{http_code}' \
      "${auth_args[@]}" \
      "${url}" 2>/tmp/securerag-jenkins-ci-curl.err || printf '000')"
  else
    code="$(curl --globoff -k -sS \
      -o "${output}" \
      -w '%{http_code}' \
      "${url}" 2>/tmp/securerag-jenkins-ci-curl.err || printf '000')"
  fi
  printf '%s' "${code: -3}"
}

diagnostic() {
  local code="$1"
  case "${code}" in
    2*) printf 'Jenkins last build API reachable: HTTP %s' "${code}" ;;
    401) printf 'HTTP 401: Jenkins token absent or invalid; set JENKINS_USER and JENKINS_TOKEN' ;;
    403) printf 'HTTP 403: authenticated user lacks permissions for job %s' "${JENKINS_JOB_NAME}" ;;
    404) printf 'HTTP 404: job %s not found; set JENKINS_JOB_NAME to the real job name' "${JENKINS_JOB_NAME}" ;;
    000) printf 'HTTP 000: Jenkins unreachable at %s' "${JENKINS_URL}" ;;
    *) printf 'Jenkins API returned HTTP %s' "${code}" ;;
  esac
}

json_contains_commit() {
  local json_file="$1"
  local commit="$2"
  [[ "${commit}" != "unknown" ]] || { printf 'false'; return 0; }
  python3 - "${json_file}" "${commit}" "${commit:0:12}" <<'PY' 2>/dev/null || printf 'false'
import json
import sys

path, full_commit, short_commit = sys.argv[1:4]
with open(path, encoding="utf-8") as handle:
    payload = json.load(handle)
serialized = json.dumps(payload)
print("true" if full_commit in serialized or short_commit in serialized else "false")
PY
}

render_build_summary() {
  local json_file="$1"
  python3 - "${json_file}" <<'PY' 2>/dev/null || true
import datetime as dt
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)

timestamp = data.get("timestamp")
when = dt.datetime.fromtimestamp(timestamp / 1000, tz=dt.timezone.utc).isoformat() if isinstance(timestamp, int) else "unknown"
result = data.get("result") or ("BUILDING" if data.get("building") else "UNKNOWN")

revision = "unknown"
for action in data.get("actions", []) or []:
    rev = (action or {}).get("lastBuiltRevision")
    if isinstance(rev, dict) and rev.get("SHA1"):
        revision = rev["SHA1"]
        break

print(f"- Build number: `{data.get('number', 'unknown')}`")
print(f"- Build result: `{result}`")
print(f"- Build timestamp UTC: `{when}`")
print(f"- Build URL: `{data.get('url', 'unknown')}`")
print(f"- Last built revision: `{revision}`")
print("")
print("### Changeset")
print("")
items = (data.get("changeSet") or {}).get("items", []) or []
if items:
    for item in items:
        commit = item.get("commitId", "unknown")
        msg = item.get("msg", "")
        print(f"- `{commit}` - {msg}")
else:
    print("- No changeset entry exposed by Jenkins API.")
PY
}

expected_commit="$(resolve_expected_commit)"
expected_short="${expected_commit:0:12}"
remote_commit="$(remote_head)"
api_url="${JENKINS_URL%/}/job/${JENKINS_JOB_NAME}/lastBuild/api/json?tree=number,result,building,timestamp,duration,url,fullDisplayName,actions[lastBuiltRevision[SHA1,branch[name]],causes[shortDescription,userName]],changeSet[items[commitId,msg,author[fullName]]]"
deadline=$((SECONDS + WAIT_SECONDS))
last_code="000"
match="false"

{
  printf '# Jenkins CI Push Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `PENDING`\n'
  printf -- '- Jenkins URL: `%s`\n' "${JENKINS_URL}"
  printf -- '- Jenkins job: `%s`\n' "${JENKINS_JOB_NAME}"
  printf -- '- Auth provided: `%s`\n' "$([[ "${#auth_args[@]}" -gt 0 ]] && printf 'yes' || printf 'no')"
  printf -- '- Expected commit: `%s`\n' "${expected_commit}"
  printf -- '- Expected short commit: `%s`\n' "${expected_short}"
  printf -- '- Remote branch: `%s/%s`\n' "${GIT_REMOTE}" "${GIT_BRANCH}"
  printf -- '- Remote HEAD: `%s`\n\n' "${remote_commit:-unavailable}"
  printf '| Check | Status | Detail |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

while (( SECONDS <= deadline )); do
  last_code="$(http_code "${api_url}" "${RAW_JSON_FILE}")"
  if [[ "${last_code}" == 2* ]]; then
    match="$(json_contains_commit "${RAW_JSON_FILE}" "${expected_commit}")"
    [[ "${match}" == "true" || "${WAIT_SECONDS}" == "0" ]] && break
  else
    [[ "${WAIT_SECONDS}" == "0" ]] && break
  fi
  sleep "${POLL_SECONDS}"
done

case "${last_code}" in
  2*) api_status="TERMINÉ" ;;
  401|403|404|000) api_status="DÉPENDANT_DE_L_ENVIRONNEMENT" ;;
  *) api_status="PARTIEL" ;;
esac

printf '| Jenkins last build API | %s | %s |\n' "${api_status}" "$(diagnostic "${last_code}")" >> "${OUT_FILE}"

if [[ "${last_code}" == 2* && "${match}" == "true" ]]; then
  commit_status="TERMINÉ"
  commit_detail="commit \`${expected_short}\` found in latest build metadata"
elif [[ "${last_code}" == 2* ]]; then
  commit_status="PARTIEL"
  commit_detail="commit \`${expected_short}\` not found in latest build metadata"
else
  commit_status="DÉPENDANT_DE_L_ENVIRONNEMENT"
  commit_detail="commit consumption cannot be checked without readable Jenkins build JSON"
fi
printf '| Expected commit in Jenkins metadata | %s | %s |\n' "${commit_status}" "${commit_detail}" >> "${OUT_FILE}"

if [[ -n "${remote_commit}" && "${remote_commit}" == "${expected_commit}" ]]; then
  printf '| Git remote HEAD | TERMINÉ | remote branch points to expected commit |\n' >> "${OUT_FILE}"
else
  printf '| Git remote HEAD | PARTIEL | remote HEAD is `%s`; expected `%s` |\n' "${remote_commit:-unavailable}" "${expected_commit}" >> "${OUT_FILE}"
fi

{
  printf '\n## Last Jenkins build summary\n\n'
  if [[ -s "${RAW_JSON_FILE}" && "${last_code}" == 2* ]]; then
    render_build_summary "${RAW_JSON_FILE}"
  else
    printf 'No readable Jenkins build JSON was captured.\n'
  fi

  printf '\n## Interpretation\n\n'
  printf -- '- `TERMINÉ` proves Jenkins exposed a latest build and, when available, that the pushed commit is visible in SCM metadata.\n'
  printf -- '- `DÉPENDANT_DE_L_ENVIRONNEMENT` covers stopped Jenkins, absent/invalid token, insufficient permissions, or a wrong `JENKINS_JOB_NAME`.\n'
  printf -- '- This proof is intentionally non-blocking unless `STRICT_JENKINS_PROOF=true`.\n'
} >> "${OUT_FILE}"

global_status="${api_status}"
if [[ "${api_status}" == "TERMINÉ" && "${commit_status}" == "TERMINÉ" ]]; then
  global_status="TERMINÉ"
elif [[ "${api_status}" == "TERMINÉ" ]]; then
  global_status="PARTIEL"
fi

python3 - "${OUT_FILE}" "${global_status}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
status = sys.argv[2]
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("- Status: `PENDING`", f"- Status: `{status}`", 1), encoding="utf-8")
PY

cp "${OUT_FILE}" "${LEGACY_OUT_FILE}"
info "Jenkins CI push proof written to ${OUT_FILE}"

if is_true "${STRICT_JENKINS_PROOF}" && [[ "${global_status}" != "TERMINÉ" ]]; then
  exit 1
fi
