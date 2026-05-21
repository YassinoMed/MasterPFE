#!/usr/bin/env bash
# Run kube-score against rendered Kustomize overlays.
#
# Modes:
#   STRICT_KUBE_SCORE=true   (default in CI) - missing binary fails the build,
#                             and ANY CRITICAL fails. WARNING > KUBE_SCORE_MAX_WARNINGS
#                             also fails.
#   STRICT_KUBE_SCORE=false  - legacy "best-effort" mode: missing binary => exit 0.
#
# Configurable thresholds (override via env in Jenkins):
#   KUBE_SCORE_MAX_CRITICAL=0   (default 0 — any CRITICAL fails)
#   KUBE_SCORE_MAX_WARNINGS=0   (default 0 — any WARNING fails in strict)
#
# Exit codes:
#   0  = OK
#   1  = thresholds exceeded
#   2  = strict mode + missing prerequisites (binary, kustomize)
#
# Status markers (used by Security Readiness Report aggregator):
#   TERMINÉ            — 0 CRITICAL, WARNING <= KUBE_SCORE_MAX_WARNINGS
#   PARTIEL            — thresholds exceeded
#   PRÊT_NON_EXÉCUTÉ   — non-strict mode, binary missing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/artifacts/security"
mkdir -p "${OUT_DIR}"
REPORT="${OUT_DIR}/kube-score-report.md"
RAW="${OUT_DIR}/kube-score-raw.txt"
STATUS_FILE="${OUT_DIR}/kube-score-status.txt"

STRICT_KUBE_SCORE="${STRICT_KUBE_SCORE:-true}"
KUBE_SCORE_MAX_CRITICAL="${KUBE_SCORE_MAX_CRITICAL:-0}"
KUBE_SCORE_MAX_WARNINGS="${KUBE_SCORE_MAX_WARNINGS:-0}"

OVERLAYS=(
  "infra/k8s/overlays/demo"
  "infra/k8s/overlays/production"
)

# ── Prerequisites ───────────────────────────────────────────
binary_missing=false
if ! command -v kube-score >/dev/null 2>&1; then
  binary_missing=true
fi

if [ "${binary_missing}" = "true" ]; then
  cat >"${REPORT}" <<EOF
# kube-score validation — Status: \`PRÊT_NON_EXÉCUTÉ\`

\`kube-score\` binary is not present in this CI agent. Install:

\`\`\`
go install github.com/zegl/kube-score/cmd/kube-score@latest
# or
brew install kube-score
\`\`\`
EOF
  echo "PRÊT_NON_EXÉCUTÉ" > "${STATUS_FILE}"

  if [ "${STRICT_KUBE_SCORE}" = "true" ]; then
    echo "[FAIL] kube-score binary missing and STRICT_KUBE_SCORE=true." >&2
    exit 2
  fi

  echo "[WARN] kube-score not installed; STRICT_KUBE_SCORE=false → exit 0." >&2
  exit 0
fi

if ! command -v kustomize >/dev/null 2>&1; then
  echo "ERREUR_OUTILLAGE" > "${STATUS_FILE}"
  echo "[ERROR] kustomize is required to render overlays." >&2
  exit 2
fi

# ── Score each overlay ──────────────────────────────────────
: > "${RAW}"
critical_total=0
warn_total=0
for overlay in "${OVERLAYS[@]}"; do
  echo "===== ${overlay} =====" | tee -a "${RAW}"
  # `kube-score score` exits 1 on findings — capture but don't propagate yet.
  out=$(kustomize build "${REPO_ROOT}/${overlay}" \
        | kube-score score --output-format ci - 2>&1 || true)
  echo "${out}" >> "${RAW}"
  c=$(echo "${out}" | grep -c '^\[CRITICAL\]' || true)
  w=$(echo "${out}" | grep -c '^\[WARNING\]' || true)
  critical_total=$((critical_total + c))
  warn_total=$((warn_total + w))
done

# ── Verdict ─────────────────────────────────────────────────
verdict="TERMINÉ"
fail_reasons=()
if [ "${critical_total}" -gt "${KUBE_SCORE_MAX_CRITICAL}" ]; then
  verdict="PARTIEL"
  fail_reasons+=("CRITICAL=${critical_total} > seuil ${KUBE_SCORE_MAX_CRITICAL}")
fi
if [ "${warn_total}" -gt "${KUBE_SCORE_MAX_WARNINGS}" ]; then
  verdict="PARTIEL"
  fail_reasons+=("WARNING=${warn_total} > seuil ${KUBE_SCORE_MAX_WARNINGS}")
fi

cat >"${REPORT}" <<EOF
# kube-score validation — Status: \`${verdict}\`

| Overlay | CRITICAL | WARNING |
|---------|---------:|--------:|
$(for o in "${OVERLAYS[@]}"; do
   c=$(grep -A 100000 "===== ${o} =====" "${RAW}" | grep -B 100000 -m 1 -E "^=====" | grep -c '^\[CRITICAL\]' || true)
   w=$(grep -A 100000 "===== ${o} =====" "${RAW}" | grep -B 100000 -m 1 -E "^=====" | grep -c '^\[WARNING\]' || true)
   echo "| \`${o}\` | ${c} | ${w} |"
 done)

**Seuils :** CRITICAL ≤ ${KUBE_SCORE_MAX_CRITICAL} · WARNING ≤ ${KUBE_SCORE_MAX_WARNINGS} · STRICT_KUBE_SCORE=${STRICT_KUBE_SCORE}

$([ ${#fail_reasons[@]} -gt 0 ] && printf -- "**Échecs :**\n%s\n" "$(printf -- '- %s\n' "${fail_reasons[@]}")" || echo "Aucun dépassement de seuil.")

Detailed log: \`artifacts/security/kube-score-raw.txt\`.
EOF
echo "${verdict}" > "${STATUS_FILE}"

if [ "${verdict}" != "TERMINÉ" ]; then
  echo "[FAIL] kube-score: ${critical_total} CRITICAL, ${warn_total} WARNING (seuils CRITICAL≤${KUBE_SCORE_MAX_CRITICAL}, WARNING≤${KUBE_SCORE_MAX_WARNINGS})." >&2
  printf -- '   - %s\n' "${fail_reasons[@]}" >&2
  exit 1
fi

echo "[OK] kube-score: ${critical_total} CRITICAL, ${warn_total} WARNING (sous seuils)."
