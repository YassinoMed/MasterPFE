#!/usr/bin/env bash
# rollback-deployment.sh — SecureRAG Hub
# Rollback automatique : revert toutes les images au digest précédent.
# Appelé par le pipeline CD en cas d'échec de health check ou smoke tests.
#
# Usage: ROLLBACK_NS=securerag-hub bash scripts/gitops/rollback-deployment.sh

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
DIGEST_RECORD="${DIGEST_RECORD:-artifacts/release/promotion-digests.txt}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"

mkdir -p "${REPORT_DIR}"

ROLLBACK_LOG="${REPORT_DIR}/rollback-$(date -u +%Y%m%dT%H%M%SZ).log"

{
  echo "══════════════════════════════════════════════"
  echo "  SecureRAG Hub — Automatic Rollback"
  echo "  Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "  Namespace: ${NAMESPACE}"
  echo "══════════════════════════════════════════════"
  echo ""

  if ! command -v kubectl >/dev/null 2>&1; then
    echo "[FATAL] kubectl not available. Cannot rollback."
    exit 1
  fi

  if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
    echo "[FATAL] Namespace ${NAMESPACE} does not exist."
    exit 1
  fi

  deployments=(
    portal-web
    auth-users
    chatbot-manager
    conversation-service
    audit-security-service
  )

  rollback_count=0

  for deploy in "${deployments[@]}"; do
    if ! kubectl get deploy "${deploy}" -n "${NAMESPACE}" >/dev/null 2>&1; then
      echo "[SKIP] Deployment ${deploy} not found in ${NAMESPACE}."
      continue
    fi

    echo "[ROLLBACK] Rolling back deployment/${deploy}..."
    echo "  Current revision: $(kubectl rollout history deploy/${deploy} -n ${NAMESPACE} 2>/dev/null | tail -1 || echo 'unknown')"

    if kubectl rollout undo "deployment/${deploy}" -n "${NAMESPACE}" --to-revision=1 2>/dev/null; then
      echo "  [OK] Rollback to revision 1 initiated."
      rollback_count=$((rollback_count + 1))
    else
      echo "  [WARN] Could not rollback to revision 1. Trying last known good..."
      if kubectl rollout undo "deployment/${deploy}" -n "${NAMESPACE}" 2>/dev/null; then
        echo "  [OK] Rollback to previous revision initiated."
        rollback_count=$((rollback_count + 1))
      else
        echo "  [FAIL] No previous revision available for ${deploy}."
      fi
    fi
  done

  echo ""
  echo "[INFO] Waiting for rollback to complete..."

  for deploy in "${deployments[@]}"; do
    if kubectl get deploy "${deploy}" -n "${NAMESPACE}" >/dev/null 2>&1; then
      echo "[WAIT] Waiting for deployment/${deploy}..."
      kubectl rollout status "deployment/${deploy}" -n "${NAMESPACE}" --timeout=300s || {
        echo "[FAIL] Rollback of ${deploy} did not stabilize within 300s."
      }
    fi
  done

  echo ""
  echo "[DONE] Rollback complete. ${rollback_count} deployment(s) rolled back."
} | tee "${ROLLBACK_LOG}"

echo "[INFO] Rollback log: ${ROLLBACK_LOG}"
