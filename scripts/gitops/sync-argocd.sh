#!/usr/bin/env bash
# =============================================================================
# sync-argocd.sh — Sync & Verify ArgoCD Status Across All Applications
# =============================================================================
# Ce script synchronise et vérifie l'état de toutes les Applications ArgoCD
# du projet SecureRAG Hub. Utilisé après un déploiement GitOps ou pour
# auditer la convergence entre Git et le cluster.
#
# Usage:
#   ./scripts/gitops/sync-argocd.sh                   # Vérifier toutes les apps
#   ./scripts/gitops/sync-argocd.sh --sync             # Forcer la synchronisation
#   ./scripts/gitops/sync-argocd.sh --sync --prune     # Sync + prune resources
#   ./scripts/gitops/sync-argocd.sh --status           # État détaillé uniquement
#   ./scripts/gitops/sync-argocd.sh --app portal-web   # Cibler une app spécifique
#   ./scripts/gitops/sync-argocd.sh --env production   # Cibler un environnement
#   ./scripts/gitops/sync-argocd.sh --output json      # Sortie JSON
#   ./scripts/gitops/sync-argocd.sh --watch            # Mode watch (continuer)
#   ./scripts/gitops/sync-argocd.sh --help             # Cette aide
#
# Dépendances:
#   - kubectl (configuré avec contexte cible)
#   - argocd CLI (optionnel, pour les opérations avancées)
#   - jq (optionnel, pour la sortie JSON)
# =============================================================================

set -euo pipefail

# --- Constants ---------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="argocd"
PROJECT="securerag-hub"
ARGOCD_SERVER="argocd.securerag.local"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
PASS_EMOJI="✓"
FAIL_EMOJI="✗"
WARN_EMOJI="⚠"

# --- Flags -------------------------------------------------------------------
DO_SYNC=false
DO_PRUNE=false
DO_STATUS_ONLY=false
SPECIFIC_APP=""
SPECIFIC_ENV=""
OUTPUT_FORMAT="text"
WATCH_MODE=false

# --- Functions ---------------------------------------------------------------

usage() {
  sed -n '3,18p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
  exit 0
}

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_deps() {
  if ! command -v kubectl &>/dev/null; then
    log_error "kubectl is required but not found."
    exit 1
  fi
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_error "Namespace '$NAMESPACE' does not exist. Is ArgoCD installed?"
    exit 1
  fi
}

get_apps() {
  local apps
  if [[ -n "$SPECIFIC_APP" ]]; then
    apps=$(kubectl get applications -n "$NAMESPACE" -o name | grep -i "securerag-${SPECIFIC_APP}" || true)
  elif [[ -n "$SPECIFIC_ENV" ]]; then
    apps=$(kubectl get applications -n "$NAMESPACE" -o name | grep -i "securerag.*${SPECIFIC_ENV}" || true)
  else
    apps=$(kubectl get applications -n "$NAMESPACE" -o name | grep "securerag" || true)
  fi
  echo "$apps"
}

get_app_status() {
  local app=$1
  kubectl get "$app" -n "$NAMESPACE" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown"
}

get_app_health() {
  local app=$1
  kubectl get "$app" -n "$NAMESPACE" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown"
}

get_app_revision() {
  local app=$1
  kubectl get "$app" -n "$NAMESPACE" -o jsonpath='{.status.sync.revision}' 2>/dev/null || echo "N/A"
}

get_app_message() {
  local app=$1
  kubectl get "$app" -n "$NAMESPACE" -o jsonpath='{.status.condition[0].message}' 2>/dev/null || echo ""
}

colorize_status() {
  local status=$1
  case "$status" in
    Synced)        echo -e "${GREEN}${status}${NC}" ;;
    OutOfSync)     echo -e "${RED}${status}${NC}" ;;
    Unknown)       echo -e "${YELLOW}${status}${NC}" ;;
    *)             echo "$status" ;;
  esac
}

colorize_health() {
  local health=$1
  case "$health" in
    Healthy)       echo -e "${GREEN}${health}${NC}" ;;
    Degraded)      echo -e "${RED}${health}${NC}" ;;
    Progressing)   echo -e "${YELLOW}${health}${NC}" ;;
    Missing)       echo -e "${RED}${health}${NC}" ;;
    Suspended)     echo -e "${CYAN}${health}${NC}" ;;
    *)             echo "$health" ;;
  esac
}

sync_app() {
  local app=$1
  local prune_flag=""
  $DO_PRUNE && prune_flag="--prune"

  log_info "Syncing $app..."
  if kubectl annotate "$app" -n "$NAMESPACE" \
    argocd.argoproj.io/refresh=hard --overwrite &>/dev/null; then
    log_ok "Refresh triggered for $app"
  fi

  if command -v argocd &>/dev/null; then
    local app_name
    app_name=$(echo "$app" | sed 's/application.argoproj.io\///')
    if argocd app sync "$app_name" $prune_flag --timeout 300 2>/dev/null; then
      log_ok "Sync completed for $app"
    else
      log_error "Sync failed for $app"
    fi
  else
    log_warn "argocd CLI not found. Manual sync required via UI."
  fi
}

print_status_text() {
  local apps=$1
  local total=0 synced=0 out_of_sync=0 degraded=0 unknown=0

  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  SecureRAG Hub — ArgoCD Application Status                    ${NC}"
  echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  printf "  %-40s %-12s %-12s %-10s\n" "APPLICATION" "SYNC STATUS" "HEALTH" "REVISION"
  echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"

  for app in $apps; do
    local app_name app_display
    app_name=$(echo "$app" | sed 's/application.argoproj.io\///')
    app_display="${app_name:0:40}"
    local status health revision
    status=$(get_app_status "$app")
    health=$(get_app_health "$app")
    revision=$(get_app_revision "$app" | head -c 10)

    total=$((total + 1))
    case "$status" in
      Synced)    synced=$((synced + 1)) ;;
      OutOfSync) out_of_sync=$((out_of_sync + 1)) ;;
      *)         unknown=$((unknown + 1)) ;;
    esac
    case "$health" in
      Degraded) degraded=$((degraded + 1)) ;;
    esac

    printf "  %-40s %b %b %-10s\n" \
      "$app_display" \
      "$(colorize_status "$status")" \
      "$(colorize_health "$health")" \
      "$revision"
  done

  echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
  echo ""
  echo -e "  ${PASS_EMOJI} Synced:     ${synced}/${total}"
  echo -e "  ${WARN_EMOJI} OutOfSync:  ${out_of_sync}/${total}"
  echo -e "  ${FAIL_EMOJI} Degraded:   ${degraded}/${total}"
  echo -e "  ${WARN_EMOJI} Unknown:    ${unknown}/${total}"
  echo ""

  if [[ $out_of_sync -eq 0 && $degraded -eq 0 ]]; then
    log_ok "All applications are healthy and in sync."
    return 0
  elif [[ $out_of_sync -gt 0 ]]; then
    log_warn "${out_of_sync} application(s) are out of sync."
  fi
  if [[ $degraded -gt 0 ]]; then
    log_error "${degraded} application(s) are degraded."
  fi
  return 1
}

print_status_json() {
  local apps=$1
  local first=true

  echo '{'
  echo '  "timestamp": "'"$(date -Iseconds)"'",'
  echo '  "project": "'"$PROJECT"'",'
  echo '  "applications": ['

  for app in $apps; do
    $first || echo ','
    first=false
    local app_name status health revision message
    app_name=$(echo "$app" | sed 's/application.argoproj.io\///')
    status=$(get_app_status "$app")
    health=$(get_app_health "$app")
    revision=$(get_app_revision "$app")
    message=$(get_app_message "$app" | tr -d '"')

    echo -n '    {'
    echo -n '"name":"'"$app_name"'",'
    echo -n '"syncStatus":"'"$status"'",'
    echo -n '"healthStatus":"'"$health"'",'
    echo -n '"revision":"'"$revision"'",'
    echo -n '"message":"'"$message"'"'
    echo -n '}'
  done

  echo ''
  echo '  ]'
  echo '}'
}

print_drift_summary() {
  local apps=$1
  local drift_count=0

  echo ""
  echo -e "${YELLOW}═══ Drift Detection Summary ═══${NC}"
  for app in $apps; do
    local app_name status
    app_name=$(echo "$app" | sed 's/application.argoproj.io\///')
    status=$(get_app_status "$app")
    if [[ "$status" != "Synced" ]]; then
      drift_count=$((drift_count + 1))
      echo -e "  ${FAIL_EMOJI} ${app_name}: ${RED}${status}${NC}"
      local message
      message=$(get_app_message "$app")
      [[ -n "$message" ]] && echo "     └─ $message"
    fi
  done
  if [[ $drift_count -eq 0 ]]; then
    echo -e "  ${GREEN}No drift detected — all apps in sync.${NC}"
  fi
}

# --- Parse Arguments ---------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync)     DO_SYNC=true; shift ;;
    --prune)    DO_PRUNE=true; shift ;;
    --status)   DO_STATUS_ONLY=true; shift ;;
    --app)      SPECIFIC_APP="$2"; shift 2 ;;
    --env)      SPECIFIC_ENV="$2"; shift 2 ;;
    --output)   OUTPUT_FORMAT="$2"; shift 2 ;;
    --watch)    WATCH_MODE=true; shift ;;
    --help)     usage ;;
    *)          log_error "Unknown option: $1"; usage ;;
  esac
done

# --- Main --------------------------------------------------------------------

main() {
  check_deps

  local apps
  apps=$(get_apps)

  if [[ -z "$apps" ]]; then
    log_warn "No SecureRAG Applications found in namespace '$NAMESPACE'."
    log_info "Expected naming pattern: securerag-*"
    exit 0
  fi

  # Sync mode
  if $DO_SYNC; then
    log_info "Starting sync for all matching applications..."
    for app in $apps; do
      sync_app "$app"
    done
    echo ""
  fi

  # Status output
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    print_status_json "$apps"
  else
    print_status_text "$apps"
    print_drift_summary "$apps"
  fi

  # Watch mode
  if $WATCH_MODE; then
    log_info "Watching application status (Ctrl+C to stop)..."
    while true; do
      sleep 10
      apps=$(get_apps)
      clear 2>/dev/null || true
      print_status_text "$apps"
    done
  fi
}

main
