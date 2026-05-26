#!/usr/bin/env bash
# post-deploy-validation.sh — Orchestrator for the complete post-deployment validation suite
#
# Runs all validation steps in order, collects results, and generates a summary.
# Critical steps fail the pipeline; optional steps are marked SKIPPED_OPTIONAL.
set -euo pipefail

NS="${NS:-securerag-hub}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
REPORT_DIR="${REPORT_DIR:-reports/postdeploy}"
SUMMARY_FILE="${REPORT_DIR}/post-deploy-summary.md"
JSON_FILE="${REPORT_DIR}/post-deploy-summary.json"
COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-infra/jenkins/secrets/cosign.pub}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-artifacts/release/promotion-digests.txt}"
REQUIRE_DIGEST_DEPLOY="${REQUIRE_DIGEST_DEPLOY:-true}"

# Optional components (do not fail if absent)
RUN_OBSERVABILITY="${RUN_OBSERVABILITY:-true}"
RUN_KYVERNO="${RUN_KYVERNO:-true}"
RUN_SIGNATURE_VERIFY="${RUN_SIGNATURE_VERIFY:-true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "${REPORT_DIR}"

# ── Result tracking ────────────────────────────────────────────────────
declare -A RESULTS
TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0
SKIPPED=0

run_step() {
  local name="$1"
  local script="$2"
  local critical="${3:-true}"
  local extra_env="${4:-}"

  TOTAL=$((TOTAL + 1))
  printf '\n══════════════════════════════════════════════════════════════\n'
  printf '  Step %d: %s\n' "${TOTAL}" "${name}"
  printf '══════════════════════════════════════════════════════════════\n\n'

  if [[ ! -f "${script}" ]]; then
    printf '[SKIP] Script not found: %s\n' "${script}"
    RESULTS["${name}"]="SKIPPED_OPTIONAL"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  set +e
  if [[ -n "${extra_env}" ]]; then
    eval "${extra_env}" bash "${script}"
  else
    bash "${script}"
  fi
  local rc=$?
  set -e

  if [[ ${rc} -eq 0 ]]; then
    RESULTS["${name}"]="OK"
    PASSED=$((PASSED + 1))
    printf '\n[✅ PASS] %s\n' "${name}"
  elif [[ "${critical}" == "true" ]]; then
    RESULTS["${name}"]="FAILED"
    FAILED=$((FAILED + 1))
    printf '\n[❌ FAIL] %s (critical)\n' "${name}"
  else
    RESULTS["${name}"]="WARNING"
    WARNINGS=$((WARNINGS + 1))
    printf '\n[⚠️  WARN] %s (non-critical, continuing)\n' "${name}"
  fi
}

# ── Execute validation steps ───────────────────────────────────────────

# P0 — Critical validations
run_step "Rollout Validation" \
  "${SCRIPT_DIR}/validate-rollout.sh" \
  true \
  "NS=${NS} REPORT_DIR=${REPORT_DIR}"

run_step "Smoke Tests" \
  "${SCRIPT_DIR}/smoke-tests.sh" \
  true \
  "NS=${NS}"

run_step "Security Smoke Tests" \
  "${SCRIPT_DIR}/security-smoke.sh" \
  false \
  "NS=${NS}"

run_step "E2E Functional Flow" \
  "${SCRIPT_DIR}/e2e-functional-flow.sh" \
  true \
  "NS=${NS} REPORT_DIR=${REPORT_DIR}"

run_step "Security Adversarial Tests" \
  "${SCRIPT_DIR}/security-adversarial-advanced.sh" \
  false \
  "NS=${NS} REPORT_DIR=${REPORT_DIR}"

run_step "Runtime Image Rollout Proof" \
  "${SCRIPT_DIR}/validate-runtime-image-rollout.sh" \
  true \
  "NS=${NS} REGISTRY_HOST=${REGISTRY_HOST} IMAGE_PREFIX=${IMAGE_PREFIX} IMAGE_TAG=${IMAGE_TAG} DIGEST_RECORD_FILE=${DIGEST_RECORD_FILE} REQUIRE_DIGEST_DEPLOY=${REQUIRE_DIGEST_DEPLOY} REPORT_FILE=${REPORT_DIR}/runtime-image-rollout-proof.md STRICT_RUNTIME_IMAGE_PROOF=false"

run_step "Kubernetes Hardening Validation" \
  "${SCRIPT_DIR}/validate-k8s-hardening.sh" \
  false \
  "NS=${NS} REPORT_DIR=${REPORT_DIR}"

run_step "Runtime Security Post-deploy" \
  "${SCRIPT_DIR}/validate-runtime-security-postdeploy.sh" \
  false \
  "NS=${NS}"

# P1 — Optional validations (non-critical)
if [[ "${RUN_SIGNATURE_VERIFY}" == "true" ]]; then
  run_step "Runtime Signature Verification" \
    "${SCRIPT_DIR}/verify-runtime-signatures.sh" \
    false \
    "NS=${NS} REGISTRY_HOST=${REGISTRY_HOST} IMAGE_PREFIX=${IMAGE_PREFIX} COSIGN_PUBLIC_KEY=${COSIGN_PUBLIC_KEY} REPORT_DIR=${REPORT_DIR}"
fi

if [[ "${RUN_KYVERNO}" == "true" ]]; then
  run_step "Kyverno Runtime Validation" \
    "${SCRIPT_DIR}/validate-kyverno-runtime.sh" \
    false
fi

if [[ "${RUN_OBSERVABILITY}" == "true" ]]; then
  run_step "Observability Validation" \
    "${SCRIPT_DIR}/validate-observability.sh" \
    false \
    "REPORT_DIR=${REPORT_DIR}"
fi

# ── Generate Summary Report ───────────────────────────────────────────
{
  printf '# Post-Deployment Validation Summary — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
  printf -- '- Image tag: `%s`\n' "${IMAGE_TAG}"
  printf -- '- Cluster context: `%s`\n\n' "$(kubectl config current-context 2>/dev/null || printf 'unknown')"

  if [[ "${FAILED}" -eq 0 ]]; then
    printf '## ✅ Overall Status: PASS\n\n'
  else
    printf '## ❌ Overall Status: FAIL (%d critical failure(s))\n\n' "${FAILED}"
  fi

  printf '| # | Validation Step | Status |\n'
  printf '|---|---|---|\n'

  step_num=0
  for key in "Rollout Validation" "Smoke Tests" "Security Smoke Tests" "E2E Functional Flow" "Security Adversarial Tests" "Runtime Image Rollout Proof" "Kubernetes Hardening Validation" "Runtime Security Post-deploy" "Runtime Signature Verification" "Kyverno Runtime Validation" "Observability Validation"; do
    result="${RESULTS[${key}]:-NOT_RUN}"
    if [[ "${result}" == "NOT_RUN" ]]; then continue; fi
    step_num=$((step_num + 1))
    case "${result}" in
      OK) icon="✅" ;;
      FAILED) icon="❌" ;;
      WARNING) icon="⚠️" ;;
      SKIPPED_OPTIONAL) icon="⏭️" ;;
      *) icon="❓" ;;
    esac
    printf '| %d | %s | %s %s |\n' "${step_num}" "${key}" "${icon}" "${result}"
  done

  printf '\n## Statistics\n\n'
  printf -- '- Total steps: %d\n' "${TOTAL}"
  printf -- '- Passed: %d\n' "${PASSED}"
  printf -- '- Failed: %d\n' "${FAILED}"
  printf -- '- Warnings: %d\n' "${WARNINGS}"
  printf -- '- Skipped: %d\n' "${SKIPPED}"
} > "${SUMMARY_FILE}"

# JSON summary
python3 -c "
import json, sys
data = {
    'generatedAt': '$(date -u '+%Y-%m-%dT%H:%M:%SZ')',
    'namespace': '${NS}',
    'registry': '${REGISTRY_HOST}',
    'imageTag': '${IMAGE_TAG}',
    'overallStatus': 'PASS' if ${FAILED} == 0 else 'FAIL',
    'total': ${TOTAL},
    'passed': ${PASSED},
    'failed': ${FAILED},
    'warnings': ${WARNINGS},
    'skipped': ${SKIPPED},
    'steps': {}
}
$(for key in "Rollout Validation" "Smoke Tests" "Security Smoke Tests" "E2E Functional Flow" "Security Adversarial Tests" "Runtime Image Rollout Proof" "Kubernetes Hardening Validation" "Runtime Security Post-deploy" "Runtime Signature Verification" "Kyverno Runtime Validation" "Observability Validation"; do
  result="${RESULTS[${key}]:-NOT_RUN}"
  if [[ "${result}" != "NOT_RUN" ]]; then
    printf "data['steps']['%s'] = '%s'\n" "${key}" "${result}"
  fi
done)
print(json.dumps(data, indent=2))
" > "${JSON_FILE}" 2>/dev/null || true

printf '\n══════════════════════════════════════════════════════════════\n'
printf '  POST-DEPLOYMENT VALIDATION COMPLETE\n'
printf '  Results: %d passed, %d failed, %d warnings, %d skipped\n' \
  "${PASSED}" "${FAILED}" "${WARNINGS}" "${SKIPPED}"
printf '  Summary: %s\n' "${SUMMARY_FILE}"
printf '══════════════════════════════════════════════════════════════\n'

if [[ "${FAILED}" -gt 0 ]]; then
  exit 1
fi
