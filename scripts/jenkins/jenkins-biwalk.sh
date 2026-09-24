#!/usr/bin/env bash
# scripts/jenkins/jenkins-biwalk.sh — Affiche un fichier côté à côté (local vs Jenkins workspace)
#  Usage: scripts/jenkins/jenkins-biwalk.sh [chemin_relatif]
set -euo pipefail

P="${1:-}"
LOCAL="/home/admin/MasterPFE/${P}"
JENKINS_URL="http://localhost:8085"

if [ -z "$P" ]; then
  echo "Usage : $0 <chemin_relatif_du_repo>"
  echo "Ex: $0 artifacts/release/sbom-index.txt"
  exit 1
fi

echo "=============================================="
echo "🗂  Côté LOCAL : ${LOCAL}"
echo "=============================================="
if [ -f "$LOCAL" ]; then
  ls -lah "$LOCAL"
else
  echo "(absent)"
fi

echo ""
echo "=============================================="
echo "☁️  Côté JENKINS (dernier build servant ${P})"
echo "=============================================="
# Cherche l'artifact dans le dernier build du job securerag-hub-ci
JENKINS_PASS="$(cat infra/jenkins/secrets/jenkins-admin-password)"
FOUND=$(curl -s -u "admin:${JENKINS_PASS}" "${JENKINS_URL}/job/securerag-hub-ci/lastBuild/api/json?tree=artifacts%5bfileName,relativePath%5d" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
rel='$P'.lstrip('./')
for a in d.get('artifacts',[]):
    if a.get('relativePath') == rel or rel in a.get('relativePath',''):
        print(a['relativePath']); break
" 2>/dev/null || true)

if [ -n "${FOUND:-}" ]; then
  echo "Trouvé: $FOUND"
else
  echo "(non archivé dans le dernier build — mais déjà accessible via /workspace/$P si présent)"
fi
