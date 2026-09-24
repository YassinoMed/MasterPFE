#!/usr/bin/env bash
# scripts/jenkins/jenkins-copy-promis.sh — Copier/Coller bidirectionnel entre Jenkins et le paste bin local
set -euo pipefail

ACTION="copy"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build|-b) BUILD="$2"; ACTION="paste"; shift 2 ;;
    --pattern) PATTERN="$2"; shift 2 ;;
    *) break ;;
  esac
done

JENKINS_PASS="$(cat infra/jenkins/secrets/jenkins-admin-password)"

if [ "$ACTION" = "copy" ]; then
  # -- copy : ./scripts/jenkins/jenkins-copy-promis.sh "texte à copier"
  echo "${1:-}" | xclip -selection clipboard 2>/dev/null || echo "xclip non installé. Installe-le : sudo apt install xclip"
  echo "✅ Copié dans le presse-papiers: '$1'"
elif [ "$ACTION" = "paste" ]; then
  # -- paste : ./scripts/jenkins/jenkins-copy-promis.sh --build 1 --pattern 'FAIL|PASS'
  TMP=/tmp/jenkins_last_build.log
  curl -s -u "admin:${JENKINS_PASS}" "http://localhost:8085/job/securerag-hub-ci/${BUILD:-lastBuild}/consoleText" > "$TMP"
  if [ -n "${PATTERN:-}" ]; then
    grep -E "${PATTERN}" "$TMP" | head -20 | xclip -selection clipboard 2>/dev/null || cat "$TMP" | grep -E "${PATTERN}" | head -20
  else
    cat "$TMP"
  fi
fi
