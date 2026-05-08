#!/usr/bin/env bash
# Lint Falco rule YAML files. Best-effort: uses the falco container if
# available; otherwise falls back to YAML well-formedness via python.
#
# Exit codes:
#   0  = rules valid (or fallback parse succeeded)
#   1  = rules invalid
#   77 = SKIPPED (no validator available)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Canonical rules file — validated by Falco engine.
RULES_FILE="${REPO_ROOT}/security/falco/custom-rules.yaml"
# ConfigMap that ships rules to the cluster — validated as YAML only.
CONFIGMAP_FILE="${REPO_ROOT}/infra/k8s/runtime-detection/configmap-rules.yaml"

OUT_DIR="${REPO_ROOT}/artifacts/security"
mkdir -p "${OUT_DIR}"
LOG="${OUT_DIR}/falco-rules-validation.log"
: > "${LOG}"

# 1. ConfigMap well-formedness (always)
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CONFIGMAP_FILE}" >>"${LOG}" 2>&1 <<'PY' || { echo "[FAIL] ConfigMap YAML invalid" | tee -a "${LOG}"; exit 1; }
import sys, yaml
with open(sys.argv[1]) as fh:
    list(yaml.safe_load_all(fh))
print(f"[OK] ConfigMap YAML well-formed: {sys.argv[1]}")
PY
  echo "[OK]   ${CONFIGMAP_FILE} (YAML)" | tee -a "${LOG}"
fi

# 2. Falco engine validation of the canonical rules file.
if command -v docker >/dev/null 2>&1; then
  echo "[INFO] Validating Falco rules via falcosecurity/falco container" | tee -a "${LOG}"
  echo "[INFO] -> ${RULES_FILE}" | tee -a "${LOG}"
  # falco-no-driver skips kmod build. Load bundled rules so built-in macros
  # (container, spawned_process, outbound, open_read, ...) resolve.
  if docker run --rm --entrypoint /usr/bin/falco \
       -v "${RULES_FILE}:/rules.yaml:ro" \
       falcosecurity/falco-no-driver:0.38.2 \
       --validate /etc/falco/falco_rules.yaml \
       --validate /rules.yaml >>"${LOG}" 2>&1
  then
    echo "[OK]   ${RULES_FILE}" | tee -a "${LOG}"
    exit 0
  else
    echo "[FAIL] ${RULES_FILE}" | tee -a "${LOG}"
    exit 1
  fi
fi

if command -v python3 >/dev/null 2>&1; then
  echo "[WARN] docker not available; YAML well-formedness only" | tee -a "${LOG}"
  python3 - "${RULES_FILE}" <<'PY' || exit 1
import sys, yaml
with open(sys.argv[1]) as fh:
    list(yaml.safe_load_all(fh))
print(f"[OK] {sys.argv[1]} (YAML well-formed only)")
PY
  exit 0
fi

echo "[SKIP] No docker or python3 available; cannot validate Falco rules." | tee -a "${LOG}"
exit 77
