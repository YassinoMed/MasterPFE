#!/usr/bin/env bash
# Rotation expert d'un recipient age pour les Secrets chiffrés SOPS.
#
# Workflow :
#   1. Générer un nouveau recipient age (pair clé privée/publique).
#   2. Mettre à jour `infra/secrets/sops/sops-age.example.yaml` (creation_rules)
#      avec le nouveau recipient public.
#   3. Re-chiffrer tous les fichiers `*.enc.yaml` du dépôt avec le nouveau
#      recipient (l'ancien est conservé en `additional-recipients` jusqu'à la
#      fenêtre de retrait).
#   4. Archiver une preuve sous `artifacts/security/sops-rotation-<ts>.md`.
#
# Variables :
#   SOPS_AGE_KEY_FILE     chemin vers la clé privée existante (lecture seule)
#   SOPS_AGE_OUT_DIR      dossier de sortie pour la nouvelle clé (def. /tmp/sops-rotation-<ts>)
#   ROTATION_REASON       texte libre (ex. "quarterly rotation")

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

ts="$(date -u '+%Y%m%dT%H%M%SZ')"
SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-${HOME}/.config/sops/age/keys.txt}"
SOPS_AGE_OUT_DIR="${SOPS_AGE_OUT_DIR:-/tmp/sops-rotation-${ts}}"
ROTATION_REASON="${ROTATION_REASON:-manual rotation}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_DIR}/sops-rotation-${ts}.md"
SOPS_CONFIG="${SOPS_CONFIG:-infra/secrets/sops/sops-age.example.yaml}"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[ERROR] missing $1" >&2; exit 2; }; }
require sops
require age-keygen

mkdir -p "${REPORT_DIR}" "${SOPS_AGE_OUT_DIR}"
chmod 700 "${SOPS_AGE_OUT_DIR}"

new_key="${SOPS_AGE_OUT_DIR}/keys.txt"
age-keygen -o "${new_key}" >/dev/null
chmod 600 "${new_key}"
new_recipient="$(grep -E '^# public key:' "${new_key}" | awk '{print $4}')"

if [[ -z "${new_recipient}" ]]; then
  echo "[ERROR] failed to derive new age recipient" >&2
  exit 3
fi

# Préserve le recipient courant comme fallback (rotation graduelle)
old_recipient="$(grep -E '^[[:space:]]*age:' "${SOPS_CONFIG}" | head -1 | sed -E "s/.*age:[[:space:]]*['\"]?([^'\" ]+).*/\1/")"

echo "[INFO] old recipient: ${old_recipient:-<none>}"
echo "[INFO] new recipient: ${new_recipient}"

# Met à jour le fichier de configuration SOPS avec les deux recipients
python3 - "${SOPS_CONFIG}" "${new_recipient}" "${old_recipient}" <<'PY'
import sys, re, pathlib
path, new_r, old_r = sys.argv[1:]
text = pathlib.Path(path).read_text(encoding="utf-8")
combined = new_r if not old_r or old_r == new_r else f"{new_r},{old_r}"
text = re.sub(r"(age:\s*)['\"]?[^'\"\n]+['\"]?",
              lambda m: f"{m.group(1)}'{combined}'", text)
pathlib.Path(path).write_text(text, encoding="utf-8")
PY

# Re-chiffre tous les fichiers SOPS
re_encrypted=()
while IFS= read -r f; do
  [[ -z "${f}" ]] && continue
  echo "[INFO] re-encrypting ${f}"
  SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE}" sops updatekeys --yes "${f}" || {
    echo "[WARN] updatekeys failed on ${f}, attempting full rotation" >&2
    tmp="$(mktemp)"
    SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE}" sops --decrypt "${f}" > "${tmp}"
    SOPS_AGE_KEY_FILE="${new_key}" sops --encrypt --age "${new_recipient}" "${tmp}" > "${f}"
    rm -f "${tmp}"
  }
  re_encrypted+=("${f}")
done < <(find infra/secrets -type f -name '*.enc.yaml' 2>/dev/null)

{
  printf '# SOPS age rotation — SecureRAG Hub\n\n'
  printf -- '- Generated UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Reason: `%s`\n' "${ROTATION_REASON}"
  printf -- '- Old recipient: `%s`\n' "${old_recipient:-<none>}"
  printf -- '- New recipient: `%s`\n' "${new_recipient}"
  printf -- '- New key file: `%s` (chmod 600, must be moved off the worktree)\n' "${new_key}"
  printf -- '- SOPS config: `%s`\n' "${SOPS_CONFIG}"
  printf -- '- Status: `TERMINÉ`\n\n'
  printf '## Re-encrypted files\n\n'
  for f in "${re_encrypted[@]}"; do
    printf -- '- `%s`\n' "${f}"
  done
  if (( ${#re_encrypted[@]} == 0 )); then
    printf -- '- (none — repository contains no \`*.enc.yaml\` yet)\n'
  fi
  printf '\n## Post-rotation actions\n\n'
  printf -- '1. Distribuer le nouveau \`keys.txt\` aux opérateurs via canal sécurisé.\n'
  printf -- '2. Importer dans Jenkins (credential `sops-age-key`).\n'
  printf -- '3. Re-déployer les secrets affectés via `make sops-db-secret`.\n'
  printf -- '4. Après fenêtre de retrait, retirer l’ancien recipient de \`%s\`.\n' "${SOPS_CONFIG}"
} > "${REPORT_FILE}"

echo "[INFO] rotation report -> ${REPORT_FILE}"
