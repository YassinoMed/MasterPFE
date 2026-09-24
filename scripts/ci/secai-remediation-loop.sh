#!/usr/bin/env bash
# Boucle remediation sécurisé — SECAI + Jenkins.
#
# Environnement obligatoire (jamais en clair dans ce script) :
#   JENKINS_AUTH      basic auth token ou user:pass
#   SECAI_MODE        advisory | strict
#   HOST_JENKINS      http://localhost:8085
#
# Ce script N'EST PAS icarsh coordinator pour la démo Python.
# Usage : ./secai-remediation-loop.sh [build_id]
set -euo pipefail

WORKSPACE="${WORKSPACE:-/home/admin/MasterPFE}"
cd "$WORKSPACE"

MAX_REBUILDS="${MAX_REBUILDS:-2}"
SECAI_MODE="${SECAI_MODE:-advisory}"
JENKINS_URL="${HOST_JENKINS:-http://localhost:8085}"

# Artifacts
REPORTS_DIR="artifacts/release"
DECISIONS_DIR="artifacts/secai/decisions"
FINDINGS_DIR="artifacts/secai/findings"
LOG_DIR="artifacts/secai"
mkdir -p "$REPORTS_DIR" "$DECISIONS_DIR" "$FINDINGS_DIR" "$LOG_DIR"

RUN_ID="${BUILD_NUMBER:-secai-loop-$(date +%Y%m%d_%H%M%S)}"
echo "[INFO] SECAI remediation loop [build-id=$RUN_ID mode=$SECAI_MODE]"

# Phase 1 — Analyse (collecte des rapports de sécurités)
python3 -m secai.pipelines.security_analysis \
  --input security/reports \
  --output "$REPORTS_DIR/secai-report.json" \
  --format json

# Phase 2 — Recharger la décision exit
VERDICT=$(python3 -c "
import json
d=json.load(open('$REPORTS_DIR/secai-report.json'))
print(d['summary']['verdict'])
" 2>/dev/null || echo "UNKNOWN")

echo "[INFO] Verdict : $VERDICT"

case "$VERDICT" in
  PASS|"")
    echo "✅ PASS — pas de blocking Il ne se fait pas."
    exit 0
    ;;
  BLOCK)
    echo "❌ BLOCK — revision humaine nécessaire"
    exit 2 ;;
  FIX_AND_REBUILD)
    ;;

  REVIEW)
    if [ "$SECAI_MODE" = "strict" ]; then
      echo "⚠️ REVIEW mode strict — builder è autorisé"
      exit 1
    else
      echo "ℹ️ REVIEW mode advisory — poster un commentaire pour la revue"
      exit 1
    fi
    ;;

  *)
    echo "Unknown verdict: $VERDICT"
    exit 1 ;;
esac

# Phase 3 — Correctifs automatiques uniquement en mode strict/validator
if [ "$VERDICT" = "FIX_AND_REBUILD" ] && [ "$SECAI_MODE" = "strict" ]; then
  : "${JENKINS_API_TOKEN:?Definir JENKINS_API_TOKEN pour trigger}"
  echo "[INFO] Triggering Jenkins build..."
  curl -s -u "${JENKINS_AUTH}" \
    -X POST "${JENKINS_URL}/job/securerag-hub-ci/build" >/dev/null
  echo "[OK] build triggered (check logs)"
fi

exit 0
