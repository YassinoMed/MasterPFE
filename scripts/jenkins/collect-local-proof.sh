#!/usr/bin/env bash

set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8085}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASSWORD="${JENKINS_PASSWORD:-change-me-now}"
TRIGGER_CI="${TRIGGER_CI:-false}"
REPORT_DIR="${REPORT_DIR:-artifacts/jenkins}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

command -v curl >/dev/null 2>&1 || { error "curl is required"; exit 2; }
mkdir -p "${REPORT_DIR}"
cookie_jar="${REPORT_DIR}/jenkins.cookies"
rm -f "${cookie_jar}"

bash scripts/jenkins/wait-for-jenkins.sh

curl --globoff -fsS -c "${cookie_jar}" -b "${cookie_jar}" -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
  "${JENKINS_URL}/api/json?tree=jobs[name,color]" \
  -o "${REPORT_DIR}/jobs.json"

if [[ "${TRIGGER_CI}" == "true" ]]; then
  crumb_file="$(mktemp)"
  curl -fsS -c "${cookie_jar}" -b "${cookie_jar}" -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
    "${JENKINS_URL}/crumbIssuer/api/json" > "${crumb_file}"
  crumb_field="$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(data["crumbRequestField"])' "${crumb_file}")"
  crumb_value="$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(data["crumb"])' "${crumb_file}")"

  curl -fsS -c "${cookie_jar}" -b "${cookie_jar}" -u "${JENKINS_USER}:${JENKINS_PASSWORD}" \
    -H "${crumb_field}: ${crumb_value}" \
    -X POST "${JENKINS_URL}/job/securerag-hub-ci/build?delay=0sec"
  rm -f "${crumb_file}"
  info "CI job triggered"
fi

curl -fsS "${JENKINS_URL}/login" -o "${REPORT_DIR}/login.html"
info "Jenkins proof artifacts written to ${REPORT_DIR}"
