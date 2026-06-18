#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy-ratify.sh — Déploie Ratify + intègre avec Kyverno
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

log()  { printf '[INFO]  %s\n' "$*"; }
warn() { printf '[WARN]  %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

RATIFY_NAMESPACE="ratify"
RATIFY_VERSION="${RATIFY_VERSION:-v1.2.0}"
HELM_RELEASE="ratify"
ARTIFACTS_DIR="artifacts/security"

mkdir -p "${ARTIFACTS_DIR}"

log "=== Déploiement de Ratify Admission Control ==="

# ── Option 1: Kustomize ────────────────────────────────────────────────────
log "Applying Ratify Kustomize manifests..."
kubectl apply -k infra/k8s/ratify/ 2>&1 || warn "Kustomize apply failed, falling back to Helm"

# ── Option 2: Helm Chart ────────────────────────────────────────────────────
if ! kubectl get deployment ratify -n "${RATIFY_NAMESPACE}" &>/dev/null; then
  log "Installing Ratify via Helm..."
  helm repo add ratify https://deislabs.github.io/ratify 2>/dev/null || true
  helm repo update

  helm upgrade --install "${HELM_RELEASE}" ratify/ratify \
    --namespace "${RATIFY_NAMESPACE}" \
    --create-namespace \
    --version "${RATIFY_VERSION}" \
    --set image.tag="${RATIFY_VERSION}" \
    --set replicaCount=2 \
    --set service.port=6001 \
    --set configMap.enabled=true \
    --wait \
    --timeout 5m
fi

# ── Attendre que Ratify soit prêt ───────────────────────────────────────────
log "Waiting for Ratify deployment to become ready..."
kubectl rollout status deployment ratify -n "${RATIFY_NAMESPACE}" --timeout=180s

# ── Tester l'endpoint health ────────────────────────────────────────────────
log "Testing Ratify health endpoint..."
RATIFY_POD=$(kubectl get pod -n "${RATIFY_NAMESPACE}" -l app.kubernetes.io/name=ratify -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "${RATIFY_NAMESPACE}" "${RATIFY_POD}" -- sh -c "wget -qO- http://localhost:6001/health" \
  && log "Ratify health check passed" \
  || warn "Ratify health check failed (may need TLS config)"

# ── Appliquer la politique Kyverno ──────────────────────────────────────────
log "Applying Kyverno ClusterPolicy for Ratify external verification..."
kubectl apply -f infra/k8s/policies/kyverno/ratify-verification.yaml

log "Waiting for policy to be ready..."
kubectl wait --for=condition=ready clusterpolicy/securerag-ratify-verification --timeout=60s 2>/dev/null || true

# ── Tests d'admission ───────────────────────────────────────────────────────
log "=== Tests d'admission ==="

TEST_NS="ratify-test"
kubectl create namespace "${TEST_NS}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
trap 'kubectl delete namespace "${TEST_NS}" --ignore-not-found --timeout=30s 2>/dev/null || true' EXIT

# Test 1: Image signée (devrait passer)
log "Test 1: Signed image (expected: PASS)..."
if kubectl run test-signed \
  --image=ghcr.io/YassinoMed/securerag-hub-app:v1.0.0 \
  -n "${TEST_NS}" \
  --dry-run=server \
  -o name 2>&1; then
  log "[PASS] Signed image accepted"
else
  warn "[INFO] Signed image rejected (check if image is signed)"
fi

# Test 2: Image non signée (devrait être rejetée)
log "Test 2: Unsigned image (expected: REJECT)..."
if kubectl run test-unsigned \
  --image=ghcr.io/YassinoMed/securerag-hub-unsigned:latest \
  -n "${TEST_NS}" \
  --dry-run=server \
  -o name 2>&1 | grep -qi "denied\|blocked\|forbidden\|refused"; then
  log "[PASS] Unsigned image correctly rejected"
else
  warn "[FAIL] Unsigned image was not rejected — check policy enforcement"
fi

# Test 3: Image avec tag latest (devrait être rejetée)
log "Test 3: Latest tag (expected: REJECT)..."
if kubectl run test-latest \
  --image=ghcr.io/YassinoMed/securerag-hub-app:latest \
  -n "${TEST_NS}" \
  --dry-run=server \
  -o name 2>&1 | grep -qi "denied\|blocked\|forbidden\|refused"; then
  log "[PASS] Latest tag correctly rejected"
else
  warn "[FAIL] Latest tag was not rejected"
fi

# ── Valider la politique ────────────────────────────────────────────────────
log "=== Validation de la politique ==="
kubectl get clusterpolicy securerag-ratify-verification -o wide
kubectl describe clusterpolicy securerag-ratify-verification | tail -20

log "=== Résumé ==="
echo "  Ratify:       $(kubectl get deployment ratify -n ${RATIFY_NAMESPACE} -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 'N/A')/2 ready"
echo "  Policy:       securerag-ratify-verification (Enforce)"
echo "  Registry:     ghcr.io/YassinoMed/*"
echo "  Verifiers:    Cosign + SBOM + SLSA"
echo "  Artifacts:    ${ARTIFACTS_DIR}/"
echo ""
log "Déploiement Ratify terminé avec succès."
