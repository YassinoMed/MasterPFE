#!/usr/bin/env bash

set -euo pipefail

SECRETS_FILE="${SECRETS_FILE:-security/secrets/.env.local}"
umask 077

info() { printf '[INFO] %s\n' "$*"; }

if [[ -f "${SECRETS_FILE}" ]]; then
  info "Local secrets file already exists at ${SECRETS_FILE}"
  chmod 600 "${SECRETS_FILE}" 2>/dev/null || true
  exit 0
fi

mkdir -p "$(dirname "${SECRETS_FILE}")"

generated_file="$(mktemp)"
trap 'rm -f "${generated_file}"' EXIT

python3 - <<'PY' > "${generated_file}"
import base64
import secrets

def token():
    return secrets.token_urlsafe(48)

app_key = "base64:" + base64.b64encode(secrets.token_bytes(32)).decode()
print(app_key)
for _ in range(5):
    print(token())
PY

app_key="$(sed -n '1p' "${generated_file}")"
cosign_password="$(sed -n '2p' "${generated_file}")"
jwt_secret="$(sed -n '3p' "${generated_file}")"
app_secret_key="$(sed -n '4p' "${generated_file}")"
db_password="$(sed -n '5p' "${generated_file}")"
shared_api_token="$(sed -n '6p' "${generated_file}")"

cat > "${SECRETS_FILE}" <<EOF
COSIGN_PASSWORD=${cosign_password}
JWT_SECRET=${jwt_secret}
APP_SECRET_KEY=${app_secret_key}
APP_KEY=${app_key}
DB_PASSWORD=${db_password}
SECURERAG_SHARED_API_TOKEN=${shared_api_token}
EOF

chmod 600 "${SECRETS_FILE}"
info "Local secrets file created at ${SECRETS_FILE}"
