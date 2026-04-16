#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
SECRET_NAME="${SECRET_NAME:-securerag-common-secrets}"
SECRETS_FILE="${SECRETS_FILE:-security/secrets/.env.local}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

command -v kubectl >/dev/null 2>&1 || { error "kubectl is required"; exit 2; }

if [[ ! -f "${SECRETS_FILE}" ]]; then
  error "Secrets file not found: ${SECRETS_FILE}"
  error "Create it from security/secrets/.env.example in a non-versioned local file."
  exit 1
fi

if [[ "$(stat -f '%Lp' "${SECRETS_FILE}" 2>/dev/null || stat -c '%a' "${SECRETS_FILE}" 2>/dev/null || printf '600')" != "600" ]]; then
  warn "Secrets file ${SECRETS_FILE} is not mode 600; fixing permissions locally."
  chmod 600 "${SECRETS_FILE}"
fi

python3 - "${SECRETS_FILE}" <<'PY'
import base64
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
required = {
    "APP_KEY",
    "APP_SECRET_KEY",
    "COSIGN_PASSWORD",
    "DB_PASSWORD",
    "JWT_SECRET",
    "SECURERAG_SHARED_API_TOKEN",
}
weak_values = {"", "change-me", "changeme", "password", "password123", "admin", "secret", "default"}
values = {}

for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip().strip('"').strip("'")

missing = sorted(required - values.keys())
if missing:
    raise SystemExit(f"missing required secret values: {', '.join(missing)}")

for key in sorted(required):
    value = values[key]
    if value.lower() in weak_values or len(value) < 32:
        raise SystemExit(f"weak or placeholder secret refused for {key}")

app_key = values["APP_KEY"]
if not app_key.startswith("base64:"):
    raise SystemExit("APP_KEY must use Laravel base64: format")

try:
    decoded = base64.b64decode(app_key.split(":", 1)[1], validate=True)
except Exception as exc:
    raise SystemExit(f"APP_KEY is not valid base64: {exc}") from exc

if len(decoded) != 32:
    raise SystemExit("APP_KEY must decode to exactly 32 bytes")

if not re.fullmatch(r"[A-Za-z0-9_\-]+", values["SECURERAG_SHARED_API_TOKEN"]):
    raise SystemExit("SECURERAG_SHARED_API_TOKEN contains unexpected characters")
PY

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-env-file="${SECRETS_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

info "Secret ${SECRET_NAME} applied to namespace ${NAMESPACE}"
