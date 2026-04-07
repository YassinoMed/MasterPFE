#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
FINAL_REPORT="${REPORT_DIR}/validation-summary.md"

mkdir -p "${REPORT_DIR}"

count_status() {
  local status="$1"
  (grep -Roh "^\\[${status}\\]" "${REPORT_DIR}" 2>/dev/null || true) | wc -l | tr -d ' '
}

PASS_COUNT="$(count_status PASS)"
FAIL_COUNT="$(count_status FAIL)"
SKIP_COUNT="$(count_status SKIP)"

cat > "${FINAL_REPORT}" <<EOF
# Rapport de validation post-déploiement — SecureRAG Hub

## Résumé global
- PASS : ${PASS_COUNT}
- FAIL : ${FAIL_COUNT}
- SKIP : ${SKIP_COUNT}

## Fichiers de rapport analysés
$(find "${REPORT_DIR}" -maxdepth 1 -type f ! -name "$(basename "${FINAL_REPORT}")" | sort | sed 's/^/- /')

## Interprétation
- **PASS** : comportement attendu vérifié.
- **FAIL** : anomalie bloquante détectée.
- **SKIP** : test non applicable ou endpoint non encore implémenté.

## Conclusion
$(if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo "Le déploiement est globalement cohérent pour le niveau courant d’implémentation."
  else
    echo "Le déploiement présente des anomalies bloquantes qui doivent être corrigées avant démonstration."
  fi)
EOF

echo "Validation summary generated at ${FINAL_REPORT}"
