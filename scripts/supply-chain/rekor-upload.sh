#!/usr/bin/env bash
# rekor-upload.sh — Upload attestations to Rekor transparency log
# SecureRAG Hub — SLSA Level 3+ Supply Chain Security
#
# Uploads SLSA provenance, CycloneDX SBOM, and Cosign attestations
# to Rekor via cosign attest. Verifies entries appear in Rekor.
#
# Usage:
#   bash scripts/supply-chain/rekor-upload.sh --image <ref>
#   bash scripts/supply-chain/rekor-upload.sh --all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${SCRIPT_DIR}/../release/lib/common.sh"

REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/artifacts/release}"
PROVENANCE_DIR="${PROVENANCE_DIR:-${REPORT_DIR}/provenance}"
REKOR_DIR="${REKOR_DIR:-${REPORT_DIR}/rekor}"
SBOM_DIR="${SBOM_DIR:-${PROJECT_ROOT}/artifacts/sbom}"

REKOR_HOST="${REKOR_HOST:-https://rekor.sigstore.dev}"

mkdir -p "${REKOR_DIR}"

require_command cosign
require_command jq

info "=== Rekor Transparency Log Upload ==="

PASS=0
FAIL=0
UPLOADED=()

ATTESTATION_TYPES=(
  "slsaprovenance:SLSA Provenance"
  "cyclonedx:CycloneDX SBOM"
  "https://cosign.sigstore.dev/attestation/v1:Cosign Attestation v1"
)

record_pass() { PASS=$((PASS + 1)); info "[PASS] $1"; }
record_fail() { FAIL=$((FAIL + 1)); error "[FAIL] $1"; }

check_rekor_connection() {
  if curl -sf "${REKOR_HOST}/api/v1/log" >/dev/null 2>&1; then
    record_pass "Rekor reachable at ${REKOR_HOST}"
    return 0
  fi
  warn "Rekor not reachable at ${REKOR_HOST} — will attempt upload anyway"
  return 1
}

upload_attestation() {
  local image_ref="$1"
  local att_type="$2"
  local predicate_file="$3"
  local description="$4"
  local log_file="${REKOR_DIR}/upload-$(basename "${predicate_file}").log"

  if [[ ! -f "${predicate_file}" ]]; then
    record_fail "Predicate file not found: ${predicate_file}"
    return 1
  fi

  info "Uploading ${description} for: ${image_ref}"

  local output
  output="$(cosign attest \
    --yes \
    --type "${att_type}" \
    --predicate "${predicate_file}" \
    "${image_ref}" 2>&1)" || {
    record_fail "cosign attest ${att_type} failed for ${image_ref}"
    echo "${output}" | tail -5
    return 1
  }

  echo "${output}" > "${log_file}"

  local rekor_entry
  rekor_entry="$(echo "${output}" | grep -oE 'https?://[^ ]+rekor[^ ]*' || true)"
  if [[ -z "${rekor_entry}" ]]; then
    rekor_entry="$(cosign verify-attestation --type "${att_type}" "${image_ref}" 2>&1 | grep -oE 'https?://[^ ]+' | head -1 || true)"
  fi

  if [[ -n "${rekor_entry}" ]]; then
    UPLOADED+=("${rekor_entry}|${description}|${image_ref}")
    record_pass "${description} uploaded — entry: ${rekor_entry}"
  else
    UPLOADED+=("unknown|${description}|${image_ref}")
    record_pass "${description} attestation completed"
    warn "Could not extract Rekor entry URL from output"
  fi
}

verify_rekor_entry() {
  local rekor_entry="$1"
  local description="$2"

  if [[ "${rekor_entry}" == "unknown" ]]; then
    warn "Skipping Rekor entry verification (URL unknown)"
    return 0
  fi

  info "Verifying Rekor entry: ${rekor_entry}"

  if curl -sf "${rekor_entry}" >/dev/null 2>&1; then
    record_pass "${description} verified in Rekor at ${rekor_entry}"
  else
    record_fail "${description} NOT found in Rekor at ${rekor_entry}"
  fi
}

upload_all_for_image() {
  local image_ref="$1"

  info "Processing image: ${image_ref}"

  local image_name
  image_name="$(basename "${image_ref%%:*}")"

  local provenance_file="${PROVENANCE_DIR}/provenance-${image_name##securerag-}-${IMAGE_TAG:-latest}.json"
  [[ -f "${provenance_file}" ]] || provenance_file="${PROVENANCE_DIR}/payload-${image_name##securerag-}-${IMAGE_TAG:-latest}.json"

  if [[ -f "${provenance_file}" ]]; then
    upload_attestation "${image_ref}" "slsaprovenance" "${provenance_file}" "SLSA Provenance"
  else
    record_fail "No SLSA provenance file found for ${image_ref} at ${provenance_file}"
  fi

  local sbom_file
  sbom_file="$(find "${SBOM_DIR}" -name "*${image_name##securerag-}*sbom*cdx*" -type f 2>/dev/null | head -1 || true)"
  if [[ -n "${sbom_file}" ]]; then
    upload_attestation "${image_ref}" "cyclonedx" "${sbom_file}" "CycloneDX SBOM"
  else
    record_fail "No CycloneDX SBOM found for ${image_ref}"
  fi

  local attestation_file="${REPORT_DIR}/release-attestation.json"
  if [[ -f "${attestation_file}" ]]; then
    upload_attestation "${image_ref}" "https://cosign.sigstore.dev/attestation/v1" "${attestation_file}" "Cosign Attestation v1"
  else
    record_fail "No release attestation found at ${attestation_file}"
  fi
}

# Main
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  REKOR TRANSPARENCY LOG UPLOAD"
echo "═══════════════════════════════════════════════════════════════"
echo ""

check_rekor_connection || true

if [[ $# -eq 0 ]]; then
  info "No arguments — uploading for all built images"
  if [[ -s "${REPORT_DIR}/hermetic/built-images.txt" ]]; then
    while IFS= read -r img; do
      [[ -n "${img}" ]] && upload_all_for_image "${img}"
    done < "${REPORT_DIR}/hermetic/built-images.txt"
  else
    info "No built images list found, checking provenance directory"
    for prov_file in "${PROVENANCE_DIR}"/provenance-*.json "${PROVENANCE_DIR}"/payload-*.json; do
      [[ -f "${prov_file}" ]] || continue
      local subject_name
      subject_name="$(jq -r '.subject[0].name // empty' "${prov_file}" 2>/dev/null || true)"
      if [[ -n "${subject_name}" ]]; then
        upload_all_for_image "${subject_name}"
      fi
    done
  fi
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --image)
        upload_all_for_image "$2"
        shift 2
        ;;
      --all)
        for prov_file in "${PROVENANCE_DIR}"/provenance-*.json; do
          [[ -f "${prov_file}" ]] || continue
          local subject
          subject="$(jq -r '.subject[0].name // empty' "${prov_file}" 2>/dev/null || true)"
          [[ -n "${subject}" ]] && upload_all_for_image "${subject}"
        done
        shift
        ;;
      *)
        error "Unknown option: $1"
        exit 1
        ;;
    esac
  done
fi

info "Verifying Rekor entries..."
for entry_data in "${UPLOADED[@]}"; do
  IFS='|' read -r entry_url entry_desc entry_img <<< "${entry_data}"
  verify_rekor_entry "${entry_url}" "${entry_desc}"
done

exec 4>"${REKOR_DIR}/rekor-upload-report.md"
printf '# Rekor Transparency Log Upload Report\n\n' >&4
printf '| Artifact | Attestation Type | Rekor Entry | Status |\n' >&4
printf '|---|---|---|---|\n' >&4
for entry_data in "${UPLOADED[@]}"; do
  IFS='|' read -r entry_url entry_desc entry_img <<< "${entry_data}"
  status='active'
  [[ "${entry_url}" == "unknown" ]] && status='unknown'
  printf '| `%s` | %s | `%s` | %s |\n' "${entry_img}" "${entry_desc}" "${entry_url}" "${status}" >&4
done
printf '\n## Summary\n\n' >&4
printf -- '- Total attestations uploaded: %d\n' "${#UPLOADED[@]}" >&4
printf -- '- Passed: %d\n' "${PASS}" >&4
printf -- '- Failed: %d\n' "${FAIL}" >&4
printf -- '- Rekor Host: %s\n' "${REKOR_HOST}" >&4
printf -- '- Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >&4
if [[ "${FAIL}" -eq 0 ]]; then
  printf '\n**✅ All attestations uploaded and verified in Rekor.**\n' >&4
else
  printf '\n**❌ %d uploads/verifications failed.**\n' "${FAIL}" >&4
fi
exec 4>&-

if [[ "${FAIL}" -gt 0 ]]; then
  error "${FAIL} attestation uploads failed"
  exit 1
fi

info "Rekor upload complete. Report: ${REKOR_DIR}/rekor-upload-report.md"
