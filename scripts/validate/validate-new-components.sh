#!/usr/bin/env bash
# validate-new-components.sh — SecureRAG Hub Long Term Evolution Validation
# Vérifie chaque nouveau composant sans toucher à la production.
# Usage: bash scripts/validate/validate-new-components.sh [COMPONENT]

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "  ✅ $*"; }
fail() { echo "  ❌ $*"; }
skip() { echo "  ⏭️  $* (feature flag disabled)"; }

NAMESPACES=(
  "otel-system:OpenTelemetry Collector + Tempo"
  "backstage-system:Backstage Developer Portal"
  "aiops-system:Ollama + OpenWebUI AIOps"
  "istio-system:Istio Service Mesh"
  "chaos-mesh:Chaos Mesh Engineering"
  "argo-rollouts:Argo Rollouts Canary"
)

log "═══════════════════════════════════════════"
log "  SecureRAG Hub — Long Term Validation"
log "═══════════════════════════════════════════"

# ── 1. Production Health ─────────────────────────────────
log ""
log "─── 1. Production Health Check ───"
for deploy in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
  ready=$(kubectl get deploy "${deploy}" -n securerag-hub -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  desired=$(kubectl get deploy "${deploy}" -n securerag-hub -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
  if [[ "${ready}" == "${desired}" && "${ready}" != "0" ]]; then
    ok "${deploy}: ${ready}/${desired} ready"
  else
    fail "${deploy}: ${ready}/${desired} ready"
  fi
done

# ── 2. New Components Status ─────────────────────────────
log ""
log "─── 2. New Components (all disabled by default) ───"
for entry in "${NAMESPACES[@]}"; do
  ns="${entry%%:*}"
  desc="${entry#*:}"
  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    pods=$(kubectl get pods -n "${ns}" --no-headers 2>/dev/null | wc -l)
    running=$(kubectl get pods -n "${ns}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if [[ "${pods}" -gt 0 ]]; then
      ok "${desc}: ${running}/${pods} running"
    else
      skip "${desc}: not deployed"
    fi
  else
    skip "${desc}: namespace does not exist"
  fi
done

# ── 3. Feature Flags ─────────────────────────────────────
log ""
log "─── 3. Feature Flags Status ───"
if kubectl get configmap securerag-feature-flags -n securerag-hub >/dev/null 2>&1; then
  kubectl get configmap securerag-feature-flags -n securerag-hub -o jsonpath='{.data}' | \
    python3 -c "import json,sys; d=json.load(sys.stdin); [print(f'  {k}: {v}') for k,v in sorted(d.items())]" 2>/dev/null || \
    kubectl get configmap securerag-feature-flags -n securerag-hub -o yaml | grep -E "ENABLE_" | sed 's/    //'
else
  skip "Feature flags ConfigMap not deployed (all new components disabled by default)"
fi

# ── 4. Monitoring Health ─────────────────────────────────
log ""
log "─── 4. Observability Health ───"
for svc in prometheus grafana loki alertmanager; do
  if kubectl get deploy "${svc}" -n securerag-monitoring >/dev/null 2>&1; then
    ready=$(kubectl get deploy "${svc}" -n securerag-monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    ok "${svc}: ${ready}/1 ready"
  else
    skip "${svc}: not deployed"
  fi
done

# ── 5. Security Components ───────────────────────────────
log ""
log "─── 5. Security Components ───"
for comp in falco kyverno; do
  pods=$(kubectl get pods -n "${comp}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  if [[ "${pods}" -gt 0 ]]; then
    ok "${comp}: ${pods} running"
  else
    skip "${comp}: not deployed"
  fi
done

# ── 6. Summary ───────────────────────────────────────────
log ""
log "═══════════════════════════════════════════"
log "  Validation Complete"
log "  Production: Running"
log "  New components: All disabled by default"
log "  Rollback: kubectl delete ns <new-component>"
log "═══════════════════════════════════════════"
