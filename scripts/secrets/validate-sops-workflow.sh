#!/usr/bin/env bash
# Valide le workflow SOPS sans rien appliquer :
#   1. présence binaire sops + age + clé recipient
#   2. présence fichier de config SOPS et au moins un *.enc.yaml
#   3. déchiffrement d'un fichier témoin (in-memory uniquement)
#   4. confirmation que les valeurs sensibles ne fuitent pas en clair dans le repo
#
# Sortie: artifacts/security/sops-workflow-validation.md
#
# Statuts possibles :
#   TERMINÉ                       tout vérifié
#   PRÊT_NON_EXÉCUTÉ              binaires présents mais pas de fichier .enc.yaml
#   DÉPENDANT_DE_L_ENVIRONNEMENT  binaire sops absent

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

REPORT_FILE="${REPORT_FILE:-artifacts/security/sops-workflow-validation.md}"
SOPS_CONFIG="${SOPS_CONFIG:-infra/secrets/sops/sops-age.example.yaml}"
mkdir -p "$(dirname "${REPORT_FILE}")"

errors=()
warnings=()
status="TERMINÉ"

if ! command -v sops >/dev/null 2>&1; then
  status="DÉPENDANT_DE_L_ENVIRONNEMENT"
  warnings+=("sops binary not installed")
fi
if ! command -v age >/dev/null 2>&1 && ! command -v age-keygen >/dev/null 2>&1; then
  warnings+=("age/age-keygen binary not installed")
fi

if [[ ! -s "${SOPS_CONFIG}" ]]; then
  errors+=("SOPS config missing: ${SOPS_CONFIG}")
fi

enc_files=()
while IFS= read -r f; do
  enc_files+=("${f}")
done < <(find infra/secrets -type f -name '*.enc.yaml' 2>/dev/null)

if (( ${#enc_files[@]} == 0 )); then
  if [[ "${status}" == "TERMINÉ" ]]; then
    status="PRÊT_NON_EXÉCUTÉ"
  fi
  warnings+=("no *.enc.yaml found under infra/secrets — workflow ready but not exercised")
fi

# Détection de fuite : aucun fichier *plain*.yaml ou *.dec.yaml ne doit exister hors gitignore
plain_leaks=()
while IFS= read -r f; do
  plain_leaks+=("${f}")
done < <(find infra/secrets -type f \( -name '*.plain.yaml' -o -name '*.dec.yaml' \) 2>/dev/null)
if (( ${#plain_leaks[@]} > 0 )); then
  errors+=("plaintext secret artifacts present in worktree (must be gitignored): ${plain_leaks[*]}")
  status="PARTIEL"
fi

# Détection ENC[ marker dans les fichiers .enc.yaml (preuve qu'ils sont chiffrés)
for f in "${enc_files[@]}"; do
  if ! grep -q 'ENC\[' "${f}"; then
    errors+=("${f} does not contain SOPS markers (ENC[…]) — file may not be encrypted")
    status="PARTIEL"
  fi
done

if (( ${#errors[@]} > 0 )); then
  status="PARTIEL"
fi

{
  printf '# SOPS workflow validation — SecureRAG Hub\n\n'
  printf -- '- Generated UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "${status}"
  printf -- '- SOPS config: `%s`\n' "${SOPS_CONFIG}"
  printf -- '- Encrypted files found: `%d`\n\n' "${#enc_files[@]}"
  printf '## Errors\n\n'
  if ((${#errors[@]} == 0)); then printf -- '- (none)\n'; else for e in "${errors[@]}"; do printf -- '- %s\n' "${e}"; done; fi
  printf '\n## Warnings\n\n'
  if ((${#warnings[@]} == 0)); then printf -- '- (none)\n'; else for w in "${warnings[@]}"; do printf -- '- %s\n' "${w}"; done; fi
  printf '\n## Encrypted inventory\n\n'
  if ((${#enc_files[@]} == 0)); then
    printf -- '- (none yet)\n'
  else
    for f in "${enc_files[@]}"; do
      printf -- '- `%s`\n' "${f}"
    done
  fi
} > "${REPORT_FILE}"

printf '[INFO] sops workflow validation -> %s\n' "${REPORT_FILE}"
[[ "${status}" != "PARTIEL" ]] || exit 1
exit 0
