#!/usr/bin/env bash
# argocd-health-check.sh — Automated ArgoCD Application Health Validation
# SecureRAG Hub — World-Class GitOps
#
# Vérifie que toutes les applications ArgoCD sont dans un état sain:
# - Sync: Synced
# - Health: Healthy
# Détecte les statuts "Unknown/Unknown" et tente une correction.
#
# Usage:
#   bash scripts/gitops/argocd-health-check.sh [--fix] [--notify]
#
# Validation:
#   bash scripts/gitops/argocd-health-check.sh  # Read-only audit
#   bash scripts/gitops/argocd-health-check.sh --fix  # Auto-fix Unknown apps
#
# Rollback:
#   git checkout -- infra/k8s/argocd/  # Revert ArgoCD manifest changes

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
FIX_MODE="${FIX_MODE:-false}"
NOTIFY="${NOTIFY:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --fix) FIX_MODE="true"; shift ;;
    --notify) NOTIFY="true"; shift ;;
    *) warn "Unknown: $1"; shift ;;
  esac
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ARGOCD — APPLICATION HEALTH CHECK"
echo "═══════════════════════════════════════════════════════════════"

# Vérifier les prérequis
if ! command -v argocd &>/dev/null; then
  error "ArgoCD CLI not found — install with:"
  error "  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x /usr/local/bin/argocd"
  exit 1
fi

if ! kubectl auth can-i list applications -n "${ARGOCD_NS}" &>/dev/null; then
  error "Cannot list ArgoCD applications: missing RBAC"
  exit 1
fi

# Récupérer toutes les apps
APPS=$(kubectl get applications -n "${ARGOCD_NS}" -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.name):\(.status.sync.status // "Unknown"):\(.status.health.status // "Unknown"):\(.spec.source.repoURL // "")"' || true)

if [ -z "${APPS}" ]; then
  warn "No ArgoCD applications found"
  exit 0
fi

TOTAL=0
SYNCED=0
HEALTHY=0
UNKNOWN=0
FAILED=0
DEGRADED=0

echo ""
printf "%-35s %-12s %-12s\n" "APPLICATION" "SYNC" "HEALTH"
printf "%-35s %-12s %-12s\n" "───────────────────────────────────" "────────────" "────────────"

while IFS=: read -r name sync health repo; do
  TOTAL=$((TOTAL + 1))
  STATUS_ICON=""

  if [ "${sync}" = "Synced" ]; then SYNCED=$((SYNCED + 1)); fi
  if [ "${health}" = "Healthy" ]; then HEALTHY=$((HEALTHY + 1)); fi

  if [ "${sync}" = "Unknown" ] || [ "${health}" = "Unknown" ]; then
    UNKNOWN=$((UNKNOWN + 1))
    STATUS_ICON="❓"
  elif [ "${sync}" = "OutOfSync" ]; then
    FAILED=$((FAILED + 1))
    STATUS_ICON="⚠️"
  elif [ "${health}" = "Degraded" ]; then
    DEGRADED=$((DEGRADED + 1))
    STATUS_ICON="🔴"
  elif [ "${sync}" = "Synced" ] && [ "${health}" = "Healthy" ]; then
    STATUS_ICON="✅"
  fi

  printf "${STATUS_ICON} %-33s %-12s %-12s\n" "${name}" "${sync}" "${health}"
done <<< "${APPS}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  SUMMARY: ${TOTAL} total | ✅ ${HEALTHY} healthy | ❓ ${UNKNOWN} unknown | ⚠️ ${FAILED} out-of-sync | 🔴 ${DEGRADED} degraded"
echo "═══════════════════════════════════════════════════════════════"

# ── Auto-fix for Unknown apps ──────────────────────────────────────
if [ "${UNKNOWN}" -gt 0 ] && [ "${FIX_MODE}" = "true" ]; then
  echo ""
  warn "Found ${UNKNOWN} Unknown status app(s) — attempting fix..."

  while IFS=: read -r name sync health repo; do
    if [ "${sync}" = "Unknown" ] || [ "${health}" = "Unknown" ]; then
      info "Fixing '${name}' — refreshing and re-syncing..."

      # 1. Hard refresh
      argocd app get "${name}" --refresh --hard-refresh 2>/dev/null || true
      sleep 2

      # 2. Sync with prune
      argocd app sync "${name}" --prune --force 2>/dev/null || true
      sleep 3

      # 3. Verify
      NEW_SYNC=$(kubectl get application "${name}" -n "${ARGOCD_NS}" -o json 2>/dev/null | jq -r '.status.sync.status // "Unknown"')
      NEW_HEALTH=$(kubectl get application "${name}" -n "${ARGOCD_NS}" -o json 2>/dev/null | jq -r '.status.health.status // "Unknown"')
      if [ "${NEW_SYNC}" = "Synced" ] && [ "${NEW_HEALTH}" = "Healthy" ]; then
        info "✅ '${name}' fixed: ${NEW_SYNC} / ${NEW_HEALTH}"
      else
        warn "⚠️ '${name}' still not healthy: ${NEW_SYNC} / ${NEW_HEALTH}"
        info "  Manual debug: kubectl describe app '${name}' -n '${ARGOCD_NS}'"
      fi
    fi
  done <<< "${APPS}"
fi

# ── Notification ────────────────────────────────────────────────────
if [ "${NOTIFY}" = "true" ] && [ "${UNKNOWN}" -gt 0 ]; then
  info "Sending notification..."
  # Placeholder for webhook integration
  # curl -X POST -H "Content-Type: application/json" \
  #   -d "{\"text\": \"ArgoCD Health Check: ${UNKNOWN} apps Unknown\"}" \
  #   "${SLACK_WEBHOOK_URL}"
fi

# Exit codes
if [ "${DEGRADED}" -gt 0 ]; then
  exit 2
elif [ "${FAILED}" -gt 0 ]; then
  exit 3
elif [ "${UNKNOWN}" -gt 0 ]; then
  exit 4
fi

exit 0
