#!/usr/bin/env bash

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-production}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/image-size-evidence.md}"

services=(
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
  portal-web
)

mkdir -p "${REPORT_DIR}"

{
  printf '# Image Size Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
  printf -- '- Image tag: `%s`\n\n' "${IMAGE_TAG}"
  printf '## Global status\n\n'
  printf 'Statut global: `PENDING`\n\n'
  printf '| Service | Status | Image | Size |\n'
  printf '|---|---:|---|---:|\n'
} > "${REPORT_FILE}"

if ! command -v docker >/dev/null 2>&1; then
  printf '| all | DÉPENDANT_DE_L_ENVIRONNEMENT | docker unavailable | n/a |\n' >> "${REPORT_FILE}"
  perl -0pi -e 's/Statut global: `PENDING`/Statut global: `DÉPENDANT_DE_L_ENVIRONNEMENT`/' "${REPORT_FILE}"
  printf '[INFO] Image size evidence written to %s\n' "${REPORT_FILE}"
  exit 0
fi

missing_count=0
for service in "${services[@]}"; do
  image="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}:${IMAGE_TAG}"
  if docker image inspect "${image}" >/dev/null 2>&1; then
    size="$(docker image inspect "${image}" --format '{{.Size}}' | awk '{printf "%.1f MiB", $1/1024/1024}')"
    printf '| `%s` | TERMINÉ | `%s` | `%s` |\n' "${service}" "${image}" "${size}" >> "${REPORT_FILE}"
  else
    missing_count=$((missing_count + 1))
    printf '| `%s` | DÉPENDANT_DE_L_ENVIRONNEMENT | `%s` | image not present locally |\n' "${service}" "${image}" >> "${REPORT_FILE}"
  fi
done

if [[ "${missing_count}" -eq 0 ]]; then
  perl -0pi -e 's/Statut global: `PENDING`/Statut global: `TERMINÉ`/' "${REPORT_FILE}"
else
  perl -0pi -e 's/Statut global: `PENDING`/Statut global: `DÉPENDANT_DE_L_ENVIRONNEMENT`/' "${REPORT_FILE}"
fi

printf '[INFO] Image size evidence written to %s\n' "${REPORT_FILE}"
