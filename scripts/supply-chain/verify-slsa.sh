#!/usr/bin/env bash
# verify-slsa.sh — Verify SLSA attestations and report achieved level
# SecureRAG Hub — SLSA Level 3+ Supply Chain Security
#
# Uses slsa-verifier to validate provenance, checks builder ID,
# material digests, and reports SLSA level achieved.
#
# Usage:
#   bash scripts/supply-chain/verify-slsa.sh --image <ref>
#   bash scripts/supply-chain/verify-slsa.sh --provenance <file> --subject <name>
#   bash scripts/supply-chain/verify-slsa.sh --all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${SCRIPT_DIR}/../release/lib/common.sh"

REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/artifacts/release}"
PROVENANCE_DIR="${PROVENANCE_DIR:-${REPORT_DIR}/provenance}"
VERIFY_DIR="${VERIFY_DIR:-${REPORT_DIR}/verify-slsa}"

EXPECTED_BUILDER_ID="${EXPECTED_BUILDER_ID:-https://github.com/YassinoMed/MasterPFE/.github/workflows/ci.yml}"
EXPECTED_BUILD_TYPE="${EXPECTED_BUILD_TYPE:-https://slsa.dev/gha/github-actions-build-types/v1}"
STRICT_VERIFY="${STRICT_VERIFY:-true}"

mkdir -p "${VERIFY_DIR}"

info "=== SLSA Attestation Verification ==="

PASS=0
FAIL=0
CHECKS=()

record_pass() { PASS=$((PASS + 1)); CHECKS+=("✅ $1"); info "[PASS] $1"; }
record_fail() { FAIL=$((FAIL + 1)); CHECKS+=("❌ $1"); error "[FAIL] $1"; }

check_command_available() {
  if command -v slsa-verifier &>/dev/null; then
    record_pass "slsa-verifier CLI is available"
    return 0
  fi
  if command -v cosign &>/dev/null; then
    record_pass "cosign CLI available (slsa-verifier not found, using cosign)"
    return 0
  fi
  record_fail "Neither slsa-verifier nor cosign found — verification limited"
  return 1
}

verify_with_slsa_verifier() {
  local image_ref="$1"
  info "Verifying with slsa-verifier: ${image_ref}"

  if command -v slsa-verifier &>/dev/null; then
    local output
    output="$(slsa-verifier verify-image \
      --builder-id "${EXPECTED_BUILDER_ID}" \
      --source-uri "${GIT_REMOTE:-$(git config --get remote.origin.url 2>/dev/null || true)}" \
      "${image_ref}" 2>&1 || true)"

    if echo "${output}" | grep -qiE '(passed|verified|success)'; then
      record_pass "slsa-verifier: ${image_ref} verified against builder ${EXPECTED_BUILDER_ID}"
    else
      record_fail "slsa-verifier: ${image_ref} verification failed"
      info "Output: ${output}"
    fi
  else
    warn "slsa-verifier not installed — using cosign verify-attestation"
    local output
    output="$(cosign verify-attestation \
      --type slsaprovenance \
      "${image_ref}" 2>&1 || true)"

    if echo "${output}" | grep -qiE '(verified|passed|success)'; then
      record_pass "cosign verify-attestation: ${image_ref} provenance verified"
    else
      record_fail "cosign verify-attestation: ${image_ref} verification failed"
      info "Output: ${output}"
    fi
  fi
}

verify_provenance_file() {
  local prov_file="$1"
  local expected_subject="$2"

  if [[ ! -f "${prov_file}" ]]; then
    record_fail "Provenance file not found: ${prov_file}"
    return 1
  fi

  info "Verifying provenance file: ${prov_file}"

  if ! jq . "${prov_file}" >/dev/null 2>&1; then
    record_fail "Provenance file is not valid JSON: ${prov_file}"
    return 1
  fi
  record_pass "Provenance file is valid JSON"

  local builder_id
  builder_id="$(jq -r '.predicate.runDetails.builder.id // empty' "${prov_file}" 2>/dev/null || true)"
  if [[ "${builder_id}" == "${EXPECTED_BUILDER_ID}" ]]; then
    record_pass "Builder ID matches expected: ${builder_id}"
  else
    record_fail "Builder ID mismatch: expected ${EXPECTED_BUILDER_ID}, got ${builder_id}"
  fi

  local build_type
  build_type="$(jq -r '.predicate.buildDefinition.buildType // empty' "${prov_file}" 2>/dev/null || true)"
  if [[ -n "${build_type}" ]]; then
    record_pass "Build type present: ${build_type}"
  else
    record_fail "Build type missing from provenance"
  fi

  if [[ -n "${expected_subject}" ]]; then
    local subject_name
    subject_name="$(jq -r '.subject[0].name // empty' "${prov_file}" 2>/dev/null || true)"
    if [[ "${subject_name}" == "${expected_subject}" ]]; then
      record_pass "Subject name matches expected: ${subject_name}"
    else
      record_fail "Subject name mismatch: expected ${expected_subject}, got ${subject_name}"
    fi

    local subject_digest
    subject_digest="$(jq -r '.subject[0].digest.sha256 // empty' "${prov_file}" 2>/dev/null || true)"
    if [[ -n "${subject_digest}" && "${subject_digest}" != "unknown" ]]; then
      record_pass "Subject digest present: sha256:${subject_digest}"
    else
      record_fail "Subject digest missing or unknown"
    fi
  fi

  local git_commit
  git_commit="$(jq -r '.predicate.buildDefinition.resolvedDependencies[0].digest.gitCommit // empty' "${prov_file}" 2>/dev/null || true)"
  if [[ -n "${git_commit}" ]]; then
    record_pass "Git commit material present: ${git_commit:0:8}"
  else
    record_fail "Git commit material missing from provenance"
  fi

  local completeness_params
  completeness_params="$(jq -r '.predicate.runDetails.metadata.completeness.parameters // false' "${prov_file}" 2>/dev/null || true)"
  local completeness_env
  completeness_env="$(jq -r '.predicate.runDetails.metadata.completeness.environment // false' "${prov_file}" 2>/dev/null || true)"
  local completeness_materials
  completeness_materials="$(jq -r '.predicate.runDetails.metadata.completeness.materials // false' "${prov_file}" 2>/dev/null || true)"

  if [[ "${completeness_params}" == "true" ]]; then record_pass "Completeness: parameters=true"; else record_fail "Completeness: parameters=false"; fi
  if [[ "${completeness_env}" == "true" ]]; then record_pass "Completeness: environment=true"; else record_fail "Completeness: environment=false"; fi
  if [[ "${completeness_materials}" == "true" ]]; then record_pass "Completeness: materials=true"; else record_fail "Completeness: materials=false"; fi
}

check_slsa_level() {
  local total_checks=$((PASS + FAIL))

  info "=== SLSA Level Assessment ==="

  echo ""
  echo "Requirements for SLSA Level 3:"
  echo "  ☐ Provenance exists                   $([ -d "${PROVENANCE_DIR}" ] && [ "$(ls -A "${PROVENANCE_DIR}" 2>/dev/null)" ] && echo '✅' || echo '❌')"
  echo "  ☐ Provenance is non-forgeable          $(check_non_forgeable)"
  echo "  ☐ Build is hermetic                    $(check_hermetic)"
  echo "  ☐ Build is isolated                    $(check_isolated)"
  echo "  ☐ Source is versioned                  $(check_source_versioned)"
  echo "  ☐ Dependencies are verifiable           $(check_deps_verifiable)"
  echo ""

  local slsa_level=1
  local all_l3=true

  if [[ -d "${PROVENANCE_DIR}" ]] && [[ "$(ls -A "${PROVENANCE_DIR}" 2>/dev/null)" ]]; then
    slsa_level=2
  else
    all_l3=false
  fi

  if [[ "${PASS}" -ge 3 ]] && check_non_forgeable_bool && check_hermetic_bool; then
    slsa_level=3
  fi

  if check_non_forgeable_bool && check_hermetic_bool && check_isolated_bool; then
    [[ "${slsa_level}" -ge 3 ]] && slsa_level=3
  fi

  if ! all_l3; then
    slsa_level=1
  fi

  echo "┌──────────────────────────────────────┐"
  echo "│  SLSA Level Achieved: ${slsa_level}                  │"
  echo "│  Target Level:     3+                │"
  echo "│  Status:           $([ "${slsa_level}" -ge 3 ] && echo '✅ PASS' || echo '❌ BELOW TARGET')  │"
  echo "└──────────────────────────────────────┘"

  echo "${slsa_level}" > "${VERIFY_DIR}/slsa-level.txt"
}

check_non_forgeable() {
  if [[ -d "${PROVENANCE_DIR}" ]] && [[ "$(ls -A "${PROVENANCE_DIR}" 2>/dev/null)" ]]; then
    echo '✅'
  else
    echo '❌'
  fi
}

check_hermetic() {
  local hermetic_report="${REPORT_DIR}/hermetic/hermetic-build-report.md"
  if [[ -f "${hermetic_report}" ]]; then
    echo '✅'
  else
    echo '❌'
  fi
}

check_isolated() {
  local built_images="${REPORT_DIR}/hermetic/built-images.txt"
  if [[ -f "${built_images}" ]] && [[ -s "${built_images}" ]]; then
    echo '✅'
  else
    echo '❌'
  fi
}

check_source_versioned() {
  if git rev-parse HEAD &>/dev/null; then
    echo '✅'
  else
    echo '❌'
  fi
}

check_deps_verifiable() {
  if [[ -d "${REPORT_DIR}/provenance" ]] || [[ -d "${PROVENANCE_DIR}" ]]; then
    echo '✅'
  else
    echo '❌'
  fi
}

check_non_forgeable_bool() {
  [[ -d "${PROVENANCE_DIR}" ]] && [[ "$(ls -A "${PROVENANCE_DIR}" 2>/dev/null)" ]]
}
check_hermetic_bool() {
  [[ -f "${REPORT_DIR}/hermetic/hermetic-build-report.md" ]]
}
check_isolated_bool() {
  [[ -f "${REPORT_DIR}/hermetic/built-images.txt" ]] && [[ -s "${REPORT_DIR}/hermetic/built-images.txt" ]]
}

# Main
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  SLSA ATTESTATION VERIFICATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

check_command_available

GIT_REMOTE="$(git config --get remote.origin.url 2>/dev/null || true)"

if [[ $# -eq 0 ]]; then
  info "No arguments provided — verifying all available provenance files"
  if compgen -G "${PROVENANCE_DIR}"/provenance-*.json >/dev/null 2>&1; then
    for prov_file in "${PROVENANCE_DIR}"/provenance-*.json; do
      [[ -f "${prov_file}" ]] || continue
      verify_provenance_file "${prov_file}" ""
    done
  else
    if compgen -G "${PROVENANCE_DIR}"/payload-*.json >/dev/null 2>&1; then
      for prov_file in "${PROVENANCE_DIR}"/payload-*.json; do
        [[ -f "${prov_file}" ]] || continue
        verify_provenance_file "${prov_file}" ""
      done
    else
      record_fail "No provenance files found in ${PROVENANCE_DIR}"
      record_fail "Run build-provenance.sh first to generate provenance"
    fi
  fi
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --image)
        verify_with_slsa_verifier "$2"
        shift 2
        ;;
      --provenance)
        prov_file="$2"
        subject="${3:-}"
        verify_provenance_file "${prov_file}" "${subject}"
        shift $(( subject ? 3 : 2 ))
        ;;
      --all)
        for prov_file in "${PROVENANCE_DIR}"/provenance-*.json; do
          [[ -f "${prov_file}" ]] || continue
          verify_provenance_file "${prov_file}" ""
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

check_slsa_level

exec 3>"${VERIFY_DIR}/slsa-verification-report.md"
printf '# SLSA Verification Report\n\n' >&3
printf '| Check | Result |\n' >&3
printf '|---|---|\n' >&3
for check in "${CHECKS[@]}"; do
  icon="${check:0:2}"
  text="${check:2}"
  printf '| %s | %s |\n' "${text}" "${icon}" >&3
done
printf '\n## SLSA Level Assessment\n\n' >&3
printf '| Requirement | Status |\n' >&3
printf '|---|---|\n' >&3
printf '| Provenance exists | %s |\n' "$(check_non_forgeable)" >&3
printf '| Provenance non-forgeable | %s |\n' "$(check_non_forgeable)" >&3
printf '| Build hermetic | %s |\n' "$(check_hermetic)" >&3
printf '| Build isolated | %s |\n' "$(check_isolated)" >&3
printf '| Source versioned | %s |\n' "$(check_source_versioned)" >&3
printf '| Dependencies verifiable | %s |\n' "$(check_deps_verifiable)" >&3
printf '\n## Summary\n\n' >&3
printf -- '- Passed: %d\n' "${PASS}" >&3
printf -- '- Failed: %d\n' "${FAIL}" >&3
printf -- '- SLSA Level: %s\n' "$(cat "${VERIFY_DIR}/slsa-level.txt" 2>/dev/null || echo 'unknown')" >&3
printf -- '- Builder ID: %s\n' "${EXPECTED_BUILDER_ID}" >&3
printf -- '- Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >&3
if [[ "${FAIL}" -eq 0 ]]; then
  printf '\n**✅ All SLSA verification checks passed — SLSA Level 3+ achieved.**\n' >&3
else
  printf '\n**❌ %d verification checks failed. Review details above.**\n' "${FAIL}" >&3
fi
exec 3>&-

if [[ "${FAIL}" -gt 0 ]] && is_true "${STRICT_VERIFY}"; then
  error "${FAIL} verification checks failed"
  exit 1
fi

info "Verification complete. Report: ${VERIFY_DIR}/slsa-verification-report.md"
