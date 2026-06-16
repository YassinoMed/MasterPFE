#!/usr/bin/env bash
# validate-deployment-health.sh — SecureRAG Hub
# Post-deploy validation complète : vérifie que tous les composants
# sont déployés, sains et opérationnels.
#
# Appelé par le pipeline CD après déploiement.
# Exit 0 = tout OK. Exit 1 = un composant est unhealthy.

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
TIMEOUT="${TIMEOUT:-300}"
REPORT="${REPORT:-artifacts/validation/deployment-health-$(date -u +%Y%m%dT%H%M%SZ).log}"

mkdir -p "$(dirname "${REPORT}")"

log()  { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "${REPORT}"; }
fail() { echo "[FAIL] $*" | tee -a "${REPORT}"; echo ""; }

# ── 1. Vérifier les Deployments ──────────────────────────────
log "═══════════════════════════════════════════"
log "  1. Deployment Health Check"
log "═══════════════════════════════════════════"

deployments=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

failed_deployments=0

for deploy in "${deployments[@]}"; do
  ready=$(kubectl get deploy "${deploy}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  desired=$(kubectl get deploy "${deploy}" -n "${NAMESPACE}" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

  if [[ "${ready}" == "${desired}" && "${ready}" != "0" ]]; then
    log "  [OK] ${deploy}: ${ready}/${desired} ready"
  else
    fail "  ${deploy}: ${ready}/${desired} ready"
    failed_deployments=$((failed_deployments + 1))
  fi
done

# ── 2. Vérifier les endpoints de santé ───────────────────────
log ""
log "═══════════════════════════════════════════"
log "  2. Endpoint Health Check"
log "═══════════════════════════════════════════"

declare -A HEALTH_ENDPOINTS=(
  [portal-web]="http://portal-web.${NAMESPACE}.svc:8081/health"
  [auth-users]="http://auth-users.${NAMESPACE}.svc:8000/api/v1/health"
  [chatbot-manager]="http://chatbot-manager.${NAMESPACE}.svc:8000/api/v1/health"
  [conversation-service]="http://conversation-service.${NAMESPACE}.svc:8000/api/v1/health"
  [audit-security-service]="http://audit-security-service.${NAMESPACE}.svc:8000/api/v1/health"
)

failed_endpoints=0

for svc in "${!HEALTH_ENDPOINTS[@]}"; do
  url="${HEALTH_ENDPOINTS[${svc}]}"

  # Utiliser un pod temporaire pour le curl (cluster interne)
  http_code=$(kubectl run "health-check-${svc}" --rm -i --restart=Never \
    --image=curlimages/curl:latest -n "${NAMESPACE}" --quiet \
    -- curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${url}" 2>/dev/null || echo "000")

  if [[ "${http_code}" == "200" ]]; then
    log "  [OK] ${svc}: HTTP ${http_code}"
  else
    fail "  ${svc}: HTTP ${http_code} (expected 200)"
    failed_endpoints=$((failed_endpoints + 1))
  fi
done

# ── 3. Vérifier les composants d'infrastructure ──────────────
log ""
log "═══════════════════════════════════════════"
log "  3. Infrastructure Components"
log "═══════════════════════════════════════════"

check_ns_pods() {
  local ns="$1" label="$2"
  local ready
  ready=$(kubectl get pods -n "${ns}" --field-selector=status.phase=Running \
    -o jsonpath='{.items[*].status.phase}' 2>/dev/null | wc -w || echo "0")
  log "  [INFO] ${label} (${ns}): ${ready} pod(s) Running"
}

check_ns_pods "securerag-monitoring" "Observability"
check_ns_pods "falco" "Falco Runtime"
check_ns_pods "kyverno" "Kyverno"
check_ns_pods "argocd" "ArgoCD"

# ── 4. Vérifier HPA ──────────────────────────────────────────
log ""
log "═══════════════════════════════════════════"
log "  4. HPA Status"
log "═══════════════════════════════════════════"

kubectl get hpa -n "${NAMESPACE}" -o wide 2>/dev/null | tee -a "${REPORT}" || \
  log "  [INFO] No HPAs found in ${NAMESPACE}"

# ── 5. Vérifier PDB ──────────────────────────────────────────
log ""
log "═══════════════════════════════════════════"
log "  5. PDB Status"
log "═══════════════════════════════════════════"

kubectl get pdb -n "${NAMESPACE}" 2>/dev/null | tee -a "${REPORT}" || \
  log "  [INFO] No PDBs found in ${NAMESPACE}"

# ── 6. Résultat ───────────────────────────────────────────────
log ""
log "═══════════════════════════════════════════"
log "  Deployment Health Summary"
log "═══════════════════════════════════════════"
log "  Failed deployments : ${failed_deployments}"
log "  Failed endpoints   : ${failed_endpoints}"
log ""
log "  Report: ${REPORT}"
log "═══════════════════════════════════════════"

total_failures=$((failed_deployments + failed_endpoints))

if [[ ${total_failures} -gt 0 ]]; then
  echo "[FAIL] ${total_failures} component(s) unhealthy. Deployment validation failed."
  exit 1
fi

echo "[PASS] All components healthy. Deployment validated."
exit 0
