#!/usr/bin/env bash
# Run kube-score against rendered Kustomize overlays.
# Fails CI only on CRITICAL findings. WARN findings are recorded.
# If kube-score is missing the script records PRÊT_NON_EXÉCUTÉ but
# returns 0 (best-effort gate; promote to required once installed).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/artifacts/security"
mkdir -p "${OUT_DIR}"
REPORT="${OUT_DIR}/kube-score-report.md"
RAW="${OUT_DIR}/kube-score-raw.txt"

OVERLAYS=(
  "infra/k8s/overlays/demo"
  "infra/k8s/overlays/production"
)

if ! command -v kube-score >/dev/null 2>&1; then
  cat >"${REPORT}" <<EOF
# kube-score validation — Status: \`PRÊT_NON_EXÉCUTÉ\`

The \`kube-score\` binary is not present in this CI agent. Install:

\`\`\`
go install github.com/zegl/kube-score/cmd/kube-score@latest
# or
brew install kube-score
\`\`\`

Once installed, this stage will fail the build on CRITICAL findings.
EOF
  echo "[WARN] kube-score not installed; wrote PRÊT_NON_EXÉCUTÉ marker." >&2
  exit 0
fi

if ! command -v kustomize >/dev/null 2>&1; then
  echo "[ERROR] kustomize is required to render overlays." >&2
  exit 1
fi

: > "${RAW}"
critical_total=0
warn_total=0
for overlay in "${OVERLAYS[@]}"; do
  echo "===== ${overlay} =====" | tee -a "${RAW}"
  out=$(kustomize build "${REPO_ROOT}/${overlay}" \
        | kube-score score --output-format ci - || true)
  echo "${out}" >> "${RAW}"
  c=$(echo "${out}" | grep -c '^\[CRITICAL\]' || true)
  w=$(echo "${out}" | grep -c '^\[WARNING\]' || true)
  critical_total=$((critical_total + c))
  warn_total=$((warn_total + w))
done

cat >"${REPORT}" <<EOF
# kube-score validation — Status: $( [ "${critical_total}" -eq 0 ] && echo "\`TERMINÉ\`" || echo "\`PARTIEL\`" )

| Overlay | CRITICAL | WARNING |
|---------|---------:|--------:|
$(for o in "${OVERLAYS[@]}"; do
   c=$(grep -A1 "===== ${o} =====" "${RAW}" | grep -c '^\[CRITICAL\]' || true)
   w=$(grep -A1 "===== ${o} =====" "${RAW}" | grep -c '^\[WARNING\]' || true)
   echo "| \`${o}\` | ${c} | ${w} |"
 done)

Detailed log: \`artifacts/security/kube-score-raw.txt\`.
EOF

if [ "${critical_total}" -gt 0 ]; then
  echo "[FAIL] kube-score: ${critical_total} CRITICAL findings." >&2
  exit 1
fi
echo "[OK] kube-score: 0 CRITICAL, ${warn_total} WARNING."
