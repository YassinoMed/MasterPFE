#!/usr/bin/env bash
# verify-model-registry.sh — Vérifie que le modèle EXÉCUTÉ correspond
# EXACTEMENT à la fiche du registry (sha256). (OWASP LLM03/LLM04)
#
# Usage :
#   bash scripts/security/verify-model-registry.sh [chemin-du-gguf]
#   GGUF par défaut : /tmp/opencode/qwen2.5-0.5b.gguf (copie importée)
#
# Sortie : 0 = conforme, 1 = MISMATCH (modèle remplacé !), 2 = introuvable
set -uo pipefail

GGUF_PATH="${1:-/tmp/opencode/qwen2.5-0.5b.gguf}"
REGISTRY="models/registry/qwen2.5-0.5b-instruct.yaml"
cd "$(dirname "$0")/../.."

if [ ! -f "$REGISTRY" ]; then
  echo "[ERROR] Fiche registry absente : $REGISTRY"
  exit 2
fi

EXPECTED_SHA=$(grep "sha256:" "$REGISTRY" | head -1 | awk '{print $2}')
EXPECTED_SIZE=$(grep "size:" "$REGISTRY" | head -1 | awk '{print $2}')
MODEL_NAME=$(grep "name:" "$REGISTRY" | head -1 | awk '{print $2}')

if [ ! -f "$GGUF_PATH" ]; then
  echo "[WARN] Artefact GGUF local introuvable ($GGUF_PATH)"
  echo "  (sur le cluster : hash via le PVC ollama-models — procédure docs)"
  exit 2
fi

ACTUAL_SHA=$(sha256sum "$GGUF_PATH" | awk '{print $1}')
ACTUAL_SIZE=$(stat -c%s "$GGUF_PATH")

echo "═══ Vérification Model Registry : $MODEL_NAME ═══"
echo "  Attendu : sha256=$EXPECTED_SHA (${EXPECTED_SIZE} octets)"
echo "  Observé : sha256=$ACTUAL_SHA (${ACTUAL_SIZE} octets)"

if [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ]; then
  if [ "$ACTUAL_SIZE" = "$EXPECTED_SIZE" ]; then
    echo "  ✅ CONFORME — le modèle exécuté est exactement celui du registry"
    exit 0
  fi
fi

echo "  🚨 MISMATCH — le modèle a été REMPLACÉ ou ALTÉRÉ !"
echo "  Action IR : playbooks/IR-402-model-substitution.md"
exit 1
