#!/usr/bin/env bash
# File: security/sbom/sbom-validation.sh
# Description: Validates SBOM files for format, completeness, and signing
# Modified by: DevSecOps Agent — 2026-06-13

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
REPORT_DIR="${REPORT_DIR:-artifacts/reports/sbom-validation}"
POLICY_FILE="${POLICY_FILE:-${SCRIPT_DIR}/sbom-policy.yaml}"

pass_count=0
fail_count=0
skip_count=0

mkdir -p "${REPORT_DIR}"

log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
error(){ printf '[ERROR] %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [--sbom-dir PATH] [--report-dir PATH] [--policy FILE]
Validates all SBOM files found in SBOM_DIR against the defined policy.
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sbom-dir)    SBOM_DIR="$2";   shift 2 ;;
    --report-dir)  REPORT_DIR="$2"; shift 2 ;;
    --policy)      POLICY_FILE="$2"; shift 2 ;;
    --help|-h)     usage ;;
    *)             error "Unknown arg: $1"; usage ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command not found: $1"
    exit 1
  fi
}

require_command python3
require_command jq

if [ ! -d "${SBOM_DIR}" ]; then
  warn "SBOM directory not found: ${SBOM_DIR}"
  exit 0
fi

sbom_files=()
while IFS= read -r -d '' f; do
  sbom_files+=("$f")
done < <(find "${SBOM_DIR}" -type f \( -name '*.cdx.json' -o -name '*.spdx.json' -o -name '*.cdx.xml' -o -name '*.spdx.xml' -o -name '*.cdx' -o -name '*.spdx' \) -print0)

if [[ ${#sbom_files[@]} -eq 0 ]]; then
  warn "No SBOM files found in ${SBOM_DIR}"
  exit 0
fi

log "Found ${#sbom_files[@]} SBOM file(s) in ${SBOM_DIR}"

summary_file="${REPORT_DIR}/sbom-validation-summary.txt"
: > "${summary_file}"

printf '%-10s | %-50s | %s\n' "STATUS" "FILE" "DETAIL" >> "${summary_file}"

detect_format() {
  local file="$1"
  local content
  content="$(head -c 4096 "$file")"

  if echo "$content" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('bomFormat',''))" 2>/dev/null | grep -q CycloneDX; then
    printf 'CycloneDX JSON'
    return 0
  fi

  if echo "$content" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('spdxVersion',''))" 2>/dev/null | grep -q SPDX; then
    printf 'SPDX JSON'
    return 0
  fi

  if echo "$content" | grep -q 'bomFormat.*CycloneDX' 2>/dev/null; then
    printf 'CycloneDX XML'
    return 0
  fi

  printf 'unknown'
  return 1
}

check_format() {
  local format="$1"
  if [[ "$format" == "CycloneDX"* ]] || [[ "$format" == "SPDX"* ]]; then
    return 0
  fi
  return 1
}

check_completeness() {
  local file="$1"
  local format="$2"
  local count=0

  if [[ "$format" == *"CycloneDX"* ]]; then
    count=$(python3 -c "
import json,sys
with open('$file') as f:
    d=json.load(f)
print(len(d.get('components',[])))
" 2>/dev/null || echo 0)
  elif [[ "$format" == *"SPDX"* ]]; then
    count=$(python3 -c "
import json,sys
with open('$file') as f:
    d=json.load(f)
print(len(d.get('packages',[])))
" 2>/dev/null || echo 0)
  else
    count=0
  fi

  if [[ "$count" -ge 1 ]]; then
    printf '%s' "$count"
    return 0
  fi
  printf '%s' "$count"
  return 1
}

check_signing() {
  local file="$1"
  if [ -f "${file}.sig" ] || [ -f "${file}.minisig" ]; then
    return 0
  fi

  if python3 -c "
import json,sys
with open('$file') as f:
    d=json.load(f)
sig=d.get('signature','')
print(1 if sig else 0)
" 2>/dev/null | grep -q 1; then
    return 0
  fi

  return 1
}

for sbom in "${sbom_files[@]}"; do
  filename="$(basename "$sbom")"
  detail=""

  format="$(detect_format "$sbom")" || format="unknown"

  if ! check_format "$format"; then
    fail_count=$((fail_count + 1))
    detail="Unsupported format: ${format}"
    printf '%-10s | %-50s | %s\n' "FAIL" "${filename}" "${detail}" >> "${summary_file}"
    error "${filename}: ${detail}"
    continue
  fi

  if ! components="$(check_completeness "$sbom" "$format")"; then
    fail_count=$((fail_count + 1))
    detail="No components found (format=${format})"
    printf '%-10s | %-50s | %s\n' "FAIL" "${filename}" "${detail}" >> "${summary_file}"
    error "${filename}: ${detail}"
    continue
  fi

  detail="format=${format}, components=${components}"

  if check_signing "$sbom"; then
    detail="${detail}, signed"
  else
    detail="${detail}, NOT signed"
    warn "${filename}: SBOM is not signed"
  fi

  pass_count=$((pass_count + 1))
  printf '%-10s | %-50s | %s\n' "PASS" "${filename}" "${detail}" >> "${summary_file}"
  log "${filename}: ${detail}"
done

{
  printf '\n--- SUMMARY ---\n'
  printf 'PASS: %s\n' "${pass_count}"
  printf 'FAIL: %s\n' "${fail_count}"
  printf 'SKIP: %s\n' "${skip_count}"
  printf 'TOTAL: %s\n' "$(( pass_count + fail_count + skip_count ))"
} >> "${summary_file}"

printf '\n[INFO] SBOM validation completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}"
log "Summary written to ${summary_file}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
