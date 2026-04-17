#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-security/reports}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/sonar-analysis.md}"
SCANNER_LOG="${SCANNER_LOG:-${REPORT_DIR}/sonar-scanner.log}"
QUALITY_GATE_JSON="${QUALITY_GATE_JSON:-${REPORT_DIR}/sonar-quality-gate.json}"
SONAR_HOST_URL="${SONAR_HOST_URL:-}"
SONAR_TOKEN="${SONAR_TOKEN:-}"
REQUIRE_SONAR="${REQUIRE_SONAR:-false}"
SONAR_QUALITY_GATE_WAIT="${SONAR_QUALITY_GATE_WAIT:-true}"
SONAR_QUALITY_GATE_TIMEOUT="${SONAR_QUALITY_GATE_TIMEOUT:-300}"

mkdir -p "${REPORT_DIR}"

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

write_status() {
  local status="$1"
  local detail="$2"

  {
    printf '# Sonar Analysis - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Detail: %s\n' "${detail}"
    printf -- '- Scanner log: `%s`\n' "${SCANNER_LOG}"
    printf -- '- Quality gate JSON: `%s`\n' "${QUALITY_GATE_JSON}"
    printf '\n## Interpretation\n\n'
    case "${status}" in
      TERMINÉ)
        printf 'Sonar analysis ran and the quality gate was accepted.\n'
        ;;
      PRÊT_NON_EXÉCUTÉ)
        printf 'Sonar analysis is configured but was not executed because the required local environment is missing.\n'
        ;;
      FAIL)
        printf 'Sonar analysis or quality gate failed. Inspect the scanner log and Sonar dashboard.\n'
        ;;
    esac
  } > "${REPORT_FILE}"
}

fail_or_skip() {
  local detail="$1"
  if is_true "${REQUIRE_SONAR}"; then
    write_status "FAIL" "${detail}"
    echo "[ERROR] ${detail}" >&2
    exit 1
  fi

  write_status "PRÊT_NON_EXÉCUTÉ" "${detail}"
  echo "[WARN] ${detail}" >&2
  exit 0
}

bash scripts/ci/validate-sonar-cpd-scope.sh

command -v sonar-scanner >/dev/null 2>&1 || fail_or_skip "sonar-scanner is not installed"
[[ -n "${SONAR_HOST_URL}" ]] || fail_or_skip "SONAR_HOST_URL is not configured"
[[ -n "${SONAR_TOKEN}" ]] || fail_or_skip "SONAR_TOKEN is not configured"

scanner_args=(
  "-Dsonar.host.url=${SONAR_HOST_URL}"
  "-Dsonar.token=${SONAR_TOKEN}"
)

if is_true "${SONAR_QUALITY_GATE_WAIT}"; then
  scanner_args+=(
    "-Dsonar.qualitygate.wait=true"
    "-Dsonar.qualitygate.timeout=${SONAR_QUALITY_GATE_TIMEOUT}"
  )
fi

set +e
sonar-scanner "${scanner_args[@]}" > "${SCANNER_LOG}" 2>&1
scanner_status=$?
set -e

if [[ "${scanner_status}" -ne 0 ]]; then
  write_status "FAIL" "sonar-scanner exited with status ${scanner_status}"
  exit "${scanner_status}"
fi

python3 - "${SCANNER_LOG}" "${QUALITY_GATE_JSON}" <<'PY'
import json
import pathlib
import re
import sys

log_path = pathlib.Path(sys.argv[1])
json_path = pathlib.Path(sys.argv[2])
text = log_path.read_text(encoding="utf-8", errors="replace")

status = "UNKNOWN"
for pattern in (
    r"QUALITY GATE STATUS:\s*([A-Z]+)",
    r"Quality Gate status:\s*([A-Z]+)",
):
    match = re.search(pattern, text)
    if match:
        status = match.group(1)
        break

payload = {
    "status": status,
    "scanner_log": str(log_path),
}
json_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

quality_status="$(python3 - "${QUALITY_GATE_JSON}" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("status", "UNKNOWN"))
PY
)"

if is_true "${SONAR_QUALITY_GATE_WAIT}" && [[ "${quality_status}" != "OK" && "${quality_status}" != "UNKNOWN" ]]; then
  write_status "FAIL" "Sonar quality gate status is ${quality_status}"
  exit 1
fi

write_status "TERMINÉ" "sonar-scanner completed; quality gate status=${quality_status}"
echo "[INFO] Sonar analysis completed. Report: ${REPORT_FILE}"
