#!/usr/bin/env bash

set -euo pipefail

SECRETS_FILE="${SECRETS_FILE:-security/secrets/.env.local}"

info() { printf '[INFO] %s\n' "$*"; }

if [[ -f "${SECRETS_FILE}" ]]; then
  info "Local secrets file already exists at ${SECRETS_FILE}"
  exit 0
fi

mkdir -p "$(dirname "${SECRETS_FILE}")"

generated_file="$(mktemp)"
trap 'rm -f "${generated_file}"' EXIT

python3 - <<'PY' > "${generated_file}"
import base64
import secrets

def token():
    return secrets.token_urlsafe(24)

app_key = "base64:" + base64.b64encode(secrets.token_bytes(32)).decode()
print(app_key)
for _ in range(4):
    print(token())
PY

app_key="$(sed -n '1p' "${generated_file}")"
cosign_password="$(sed -n '2p' "${generated_file}")"
jwt_secret="$(sed -n '3p' "${generated_file}")"
app_secret_key="$(sed -n '4p' "${generated_file}")"
db_password="$(sed -n '5p' "${generated_file}")"
qdrant_api_key="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"

cat > "${SECRETS_FILE}" <<EOF
COSIGN_PASSWORD=${cosign_password}
JWT_SECRET=${jwt_secret}
APP_SECRET_KEY=${app_secret_key}
APP_KEY=${app_key}
DB_PASSWORD=${db_password}
QDRANT_API_KEY=${qdrant_api_key}
EOF

chmod 600 "${SECRETS_FILE}"
info "Local secrets file created at ${SECRETS_FILE}"
