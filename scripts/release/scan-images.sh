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
TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
TRIVY_IGNORE_UNFIXED="${TRIVY_IGNORE_UNFIXED:-true}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"
ALLOW_IMAGE_VULNERABILITIES="${ALLOW_IMAGE_VULNERABILITIES:-false}"

init_services_array

SUMMARY_FILE="${REPORT_DIR}/image-scan-summary.txt"
pass_count=0
fail_count=0
skip_count=0

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

require_command trivy
require_command python3
mkdir -p "${REPORT_DIR}" "${IMAGE_SCAN_DIR}"

{
  printf '# SecureRAG Hub image vulnerability scan summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Trivy version: %s\n' "$(trivy --version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf '# Severity gate: %s\n' "${TRIVY_SEVERITY}"
  printf '%-6s | %-18s | %-64s | %-48s | %s\n' \
    "STATUS" "SERVICE" "IMAGE" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

for service in "${SERVICES_ARRAY[@]}"; do
  image_ref="$(build_image_ref "${service}")"
  report_file="${IMAGE_SCAN_DIR}/trivy-image-${service}.json"
  log_file="${REPORT_DIR}/${service}-image-scan.log"

  if ! image_reachable_in_registry "${image_ref}"; then
    message="image is not reachable in the registry"
    if is_true "${ALLOW_MISSING_IMAGES}"; then
      skip_count=$((skip_count + 1))
      record_result "SKIP" "${service}" "${image_ref}" "-" "${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "-" "${message}"
    continue
  fi

  trivy_args=(
    image
    --format json
    --output "${report_file}"
    --severity "${TRIVY_SEVERITY}"
    --exit-code 1
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

  vuln_count="$(python3 - "${report_file}" <<'PY' 2>/dev/null || printf 'n/a'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
total = 0
for result in payload.get("Results", []):
    total += len(result.get("Vulnerabilities") or [])
print(total)
PY
)"

  if [[ "${status}" -eq 0 ]]; then
    pass_count=$((pass_count + 1))
    record_result "PASS" "${service}" "${image_ref}" "${report_file}" "vulnerabilities=${vuln_count}"
  elif is_true "${ALLOW_IMAGE_VULNERABILITIES}"; then
    skip_count=$((skip_count + 1))
    record_result "SKIP" "${service}" "${image_ref}" "${report_file}" "vulnerability gate bypassed; vulnerabilities=${vuln_count}"
  else
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "${report_file}" "vulnerabilities=${vuln_count}; see ${log_file}"
  fi
done

printf '\n[INFO] Image scanning completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"

if (( fail_count > 0 )); then
  exit 1
fi
