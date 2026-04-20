#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
IMAGE_SCAN_DIR="${IMAGE_SCAN_DIR:-security/reports}"
TRIVY_REPORT_SEVERITY="${TRIVY_REPORT_SEVERITY:-HIGH,CRITICAL}"
TRIVY_BLOCKING_SEVERITY="${TRIVY_BLOCKING_SEVERITY:-CRITICAL}"
TRIVY_FAIL_ON_HIGH="${TRIVY_FAIL_ON_HIGH:-false}"
TRIVY_IGNORE_UNFIXED="${TRIVY_IGNORE_UNFIXED:-true}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"
ALLOW_IMAGE_VULNERABILITIES="${ALLOW_IMAGE_VULNERABILITIES:-false}"

init_services_array

SUMMARY_FILE="${REPORT_DIR}/image-scan-summary.txt"
SUMMARY_MD="${REPORT_DIR}/image-scan-summary.md"
INDEX_JSON="${REPORT_DIR}/image-scan-index.json"
INDEX_JSONL="${REPORT_DIR}/image-scan-index.jsonl"
pass_count=0
fail_count=0
skip_count=0
warn_count=0

record_result() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local artifact="$4"
  local detail="$5"

  printf '%-6s | %-18s | %-64s | %-48s | %s\n' \
    "${status}" "${service}" "${image_ref}" "${artifact}" "${detail}" \
    | tee -a "${SUMMARY_FILE}"
}

record_markdown_row() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local critical_count="$4"
  local high_count="$5"
  local artifact="$6"
  local detail="$7"

  printf '| `%s` | `%s` | `%s` | %s | %s | `%s` | %s |\n' \
    "${service}" "${image_ref}" "${status}" "${critical_count}" "${high_count}" "${artifact}" "${detail}" \
    >> "${SUMMARY_MD}"
}

record_json_entry() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local artifact="$4"
  local log_file="$5"
  local critical_count="$6"
  local high_count="$7"
  local total_count="$8"
  local detail="$9"

  python3 - "${INDEX_JSONL}" "${status}" "${service}" "${image_ref}" "${artifact}" "${log_file}" \
    "${critical_count}" "${high_count}" "${total_count}" "${detail}" <<'PY'
import json
import sys

path, status, service, image_ref, artifact, log_file, critical, high, total, detail = sys.argv[1:]

def to_int(value):
    try:
        return int(value)
    except ValueError:
        return None

entry = {
    "status": status,
    "service": service,
    "image": image_ref,
    "artifact": None if artifact == "-" else artifact,
    "log": None if log_file == "-" else log_file,
    "severity_counts": {
        "CRITICAL": to_int(critical),
        "HIGH": to_int(high),
        "TOTAL": to_int(total),
    },
    "detail": detail,
}

with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(entry, sort_keys=True) + "\n")
PY
}

scan_counts() {
  local report_file="$1"

  python3 - "${report_file}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

counts = {"CRITICAL": 0, "HIGH": 0}
total = 0
for result in payload.get("Results", []):
    for vuln in result.get("Vulnerabilities") or []:
        severity = str(vuln.get("Severity", "")).upper()
        if severity in counts:
            counts[severity] += 1
        total += 1

print(f"{counts['CRITICAL']} {counts['HIGH']} {total}")
PY
}

blocking_count() {
  local critical_count="$1"
  local high_count="$2"
  local count=0
  local severity

  IFS=',' read -r -a blocking_severities <<< "${TRIVY_BLOCKING_SEVERITY}"
  for severity in "${blocking_severities[@]}"; do
    severity="${severity^^}"
    severity="${severity//[[:space:]]/}"
    case "${severity}" in
      CRITICAL)
        count=$((count + critical_count))
        ;;
      HIGH)
        count=$((count + high_count))
        ;;
    esac
  done

  if is_true "${TRIVY_FAIL_ON_HIGH}"; then
    count=$((count + high_count))
  fi

  printf '%s' "${count}"
}

require_command trivy
require_command python3
mkdir -p "${REPORT_DIR}" "${IMAGE_SCAN_DIR}"
: > "${INDEX_JSONL}"

{
  printf '# SecureRAG Hub image vulnerability scan summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Trivy version: %s\n' "$(trivy --version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf '# Reported severities: %s\n' "${TRIVY_REPORT_SEVERITY}"
  printf '# Blocking severities: %s\n' "${TRIVY_BLOCKING_SEVERITY}"
  printf '# HIGH policy: %s\n' "$(is_true "${TRIVY_FAIL_ON_HIGH}" && printf 'blocking' || printf 'reported-non-blocking')"
  printf '%-6s | %-18s | %-64s | %-48s | %s\n' \
    "STATUS" "SERVICE" "IMAGE" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

{
  printf '# Trivy Image Scan Summary - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Trivy version: `%s`\n' "$(trivy --version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf -- '- Reported severities: `%s`\n' "${TRIVY_REPORT_SEVERITY}"
  printf -- '- Blocking severities: `%s`\n' "${TRIVY_BLOCKING_SEVERITY}"
  printf -- '- HIGH policy: `%s`\n\n' "$(is_true "${TRIVY_FAIL_ON_HIGH}" && printf 'blocking' || printf 'reported-non-blocking')"
  printf '| Service | Image | Status | Critical | High | JSON report | Detail |\n'
  printf '|---|---|---:|---:|---:|---|---|\n'
} > "${SUMMARY_MD}"

for service in "${SERVICES_ARRAY[@]}"; do
  image_ref="$(build_image_ref "${service}")"
  report_file="${IMAGE_SCAN_DIR}/trivy-image-${service}.json"
  log_file="${REPORT_DIR}/${service}-image-scan.log"

  if ! image_reachable_in_registry "${image_ref}"; then
    message="image is not reachable in the registry"
    if is_true "${ALLOW_MISSING_IMAGES}"; then
      skip_count=$((skip_count + 1))
      record_result "SKIP" "${service}" "${image_ref}" "-" "${message}"
      record_markdown_row "SKIP" "${service}" "${image_ref}" "0" "0" "-" "${message}"
      record_json_entry "SKIP" "${service}" "${image_ref}" "-" "-" "0" "0" "0" "${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "-" "${message}"
    record_markdown_row "FAIL" "${service}" "${image_ref}" "0" "0" "-" "${message}"
    record_json_entry "FAIL" "${service}" "${image_ref}" "-" "-" "0" "0" "0" "${message}"
    continue
  fi

  trivy_args=(
    image
    --format json
    --output "${report_file}"
    --severity "${TRIVY_REPORT_SEVERITY}"
    --exit-code 0
  )

  if [[ -f security/trivy/trivy.yaml ]]; then
    trivy_args+=(--config security/trivy/trivy.yaml)
  fi

  if [[ -f .trivyignore ]]; then
    trivy_args+=(--ignorefile .trivyignore)
  fi

  if is_true "${TRIVY_IGNORE_UNFIXED}"; then
    trivy_args+=(--ignore-unfixed)
  fi

  set +e
  trivy "${trivy_args[@]}" "${image_ref}" > "${log_file}" 2>&1
  status=$?
  set -e

  if [[ "${status}" -ne 0 || ! -s "${report_file}" ]]; then
    fail_count=$((fail_count + 1))
    detail="Trivy scan failed before producing a usable JSON report; see ${log_file}"
    record_result "FAIL" "${service}" "${image_ref}" "${log_file}" "${detail}"
    record_markdown_row "FAIL" "${service}" "${image_ref}" "0" "0" "${log_file}" "${detail}"
    record_json_entry "FAIL" "${service}" "${image_ref}" "-" "${log_file}" "0" "0" "0" "${detail}"
    continue
  fi

  read -r critical_count high_count vuln_count < <(scan_counts "${report_file}")
  blocked_findings="$(blocking_count "${critical_count}" "${high_count}")"

  if [[ "${blocked_findings}" -eq 0 ]]; then
    pass_count=$((pass_count + 1))
    detail="critical=${critical_count}; high=${high_count}; total=${vuln_count}"
    status_label="PASS"
    if [[ "${high_count}" -gt 0 ]] && ! is_true "${TRIVY_FAIL_ON_HIGH}" && [[ "${TRIVY_BLOCKING_SEVERITY^^}" != *HIGH* ]]; then
      warn_count=$((warn_count + 1))
      status_label="WARN"
      detail="${detail}; HIGH findings are reported but non-blocking by policy"
    fi
    record_result "${status_label}" "${service}" "${image_ref}" "${report_file}" "${detail}"
    record_markdown_row "${status_label}" "${service}" "${image_ref}" "${critical_count}" "${high_count}" "${report_file}" "${detail}"
    record_json_entry "${status_label}" "${service}" "${image_ref}" "${report_file}" "${log_file}" "${critical_count}" "${high_count}" "${vuln_count}" "${detail}"
  elif is_true "${ALLOW_IMAGE_VULNERABILITIES}"; then
    skip_count=$((skip_count + 1))
    detail="vulnerability gate bypassed; critical=${critical_count}; high=${high_count}; total=${vuln_count}"
    record_result "SKIP" "${service}" "${image_ref}" "${report_file}" "${detail}"
    record_markdown_row "SKIP" "${service}" "${image_ref}" "${critical_count}" "${high_count}" "${report_file}" "${detail}"
    record_json_entry "SKIP" "${service}" "${image_ref}" "${report_file}" "${log_file}" "${critical_count}" "${high_count}" "${vuln_count}" "${detail}"
  else
    fail_count=$((fail_count + 1))
    detail="blocking_findings=${blocked_findings}; critical=${critical_count}; high=${high_count}; total=${vuln_count}; see ${log_file}"
    record_result "FAIL" "${service}" "${image_ref}" "${report_file}" "${detail}"
    record_markdown_row "FAIL" "${service}" "${image_ref}" "${critical_count}" "${high_count}" "${report_file}" "${detail}"
    record_json_entry "FAIL" "${service}" "${image_ref}" "${report_file}" "${log_file}" "${critical_count}" "${high_count}" "${vuln_count}" "${detail}"
  fi
done

python3 - "${INDEX_JSONL}" "${INDEX_JSON}" <<'PY'
import json
import sys

jsonl_path, json_path = sys.argv[1:]
entries = []
with open(jsonl_path, encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if line:
            entries.append(json.loads(line))

with open(json_path, "w", encoding="utf-8") as handle:
    json.dump({"images": entries}, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

rm -f "${INDEX_JSONL}"

{
  printf '\n## Gate result\n\n'
  printf -- '- PASS: `%s`\n' "${pass_count}"
  printf -- '- FAIL: `%s`\n' "${fail_count}"
  printf -- '- SKIP: `%s`\n' "${skip_count}"
  printf -- '- Evidence index: `%s`\n' "${INDEX_JSON}"
} >> "${SUMMARY_MD}"

printf '\n[INFO] Image scanning completed: PASS=%s FAIL=%s SKIP=%s WARN=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" "${warn_count}" | tee -a "${SUMMARY_FILE}"
info "Image scan Markdown summary: ${SUMMARY_MD}"
info "Image scan evidence index: ${INDEX_JSON}"

if (( fail_count > 0 )); then
  exit 1
fi
