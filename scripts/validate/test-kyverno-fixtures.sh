#!/usr/bin/env bash
# Runner pour les fixtures admission Kyverno (P0-9).
#
# Pour chaque YAML dans tests/admission/{positive,negative}/, exécute
#   kubectl apply --dry-run=server -f <file>
# et vérifie que le verdict matche le sous-dossier (positive=accept,
# negative=reject).
#
# Sortie :
#   - artifacts/security/kyverno-fixtures-tests.md
#   - exit 0 si 100% conforme ; exit 1 sinon

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

REPORT="${REPORT:-artifacts/security/kyverno-fixtures-tests.md}"
mkdir -p "$(dirname "${REPORT}")"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[FAIL] missing $1" >&2; exit 2; }; }
require kubectl

if ! kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
  cat > "${REPORT}" <<EOF
# Kyverno fixtures tests — Status: \`DÉPENDANT_DE_L_ENVIRONNEMENT\`

Kyverno CRDs not installed in target cluster. Skipped.
EOF
  echo "[SKIP] Kyverno not installed."
  exit 0
fi

failures=0
total=0
results=()

run_one() {
  local file="$1" expected="$2"
  total=$((total + 1))

  if out=$(kubectl apply --dry-run=server --validate=true -f "${file}" 2>&1); then
    actual="ACCEPT"
  else
    actual="REJECT"
  fi

  if [ "${actual}" = "${expected}" ]; then
    results+=("PASS|${expected}|${actual}|${file}|-")
    echo "[PASS] ${file} → ${actual} (expected ${expected})"
  else
    failures=$((failures + 1))
    excerpt=$(echo "${out}" | grep -iE 'denied|policy|kyverno' | head -1 | sed 's/|/⎮/g' || true)
    results+=("FAIL|${expected}|${actual}|${file}|${excerpt}")
    echo "[FAIL] ${file} → ${actual} (expected ${expected})" >&2
    echo "       ${excerpt}" >&2
  fi
}

shopt -s nullglob
for f in tests/admission/positive/*.yaml; do
  run_one "${f}" "ACCEPT"
done
for f in tests/admission/negative/*.yaml; do
  run_one "${f}" "REJECT"
done
shopt -u nullglob

verdict="TERMINÉ"
[ "${failures}" -gt 0 ] && verdict="PARTIEL"

{
  echo "# Kyverno fixtures tests — Status: \`${verdict}\`"
  echo
  echo "_Generated UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_"
  echo
  echo "**${total} cas, ${failures} échec(s).**"
  echo
  echo "| Result | Expected | Actual | Fixture | Detail |"
  echo "|:------:|:--------:|:------:|---------|--------|"
  for r in "${results[@]}"; do
    IFS='|' read -r res exp act file det <<< "${r}"
    icon="✅"; [ "${res}" = "FAIL" ] && icon="❌"
    printf '| %s %s | %s | %s | `%s` | %s |\n' "${icon}" "${res}" "${exp}" "${act}" "${file}" "${det}"
  done
} > "${REPORT}"

echo "[INFO] Report: ${REPORT}"
[ "${failures}" -eq 0 ] || exit 1
