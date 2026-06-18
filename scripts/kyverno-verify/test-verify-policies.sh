#!/usr/bin/env bash
# File: scripts/kyverno-verify/test-verify-policies.sh
# Description: Teste les politiques Kyverno de vérification d'images.
# Date: 2026-06-18
set -euo pipefail

NAMESPACE="securerag-hub"
PASS=0
FAIL=0

echo "=========================================="
echo "  Test des politiques Kyverno Verify"
echo "=========================================="
echo ""

cleanup() {
  kubectl delete pod securerag-test-signed  -n "${NAMESPACE}" --ignore-not-found --wait=true --timeout=30s 2>/dev/null || true
  kubectl delete pod securerag-test-unsigned -n "${NAMESPACE}" --ignore-not-found --wait=true --timeout=30s 2>/dev/null || true
  kubectl delete pod securerag-test-nosbom   -n "${NAMESPACE}" --ignore-not-found --wait=true --timeout=30s 2>/dev/null || true
  kubectl delete pod securerag-test-latest   -n "${NAMESPACE}" --ignore-not-found --wait=true --timeout=30s 2>/dev/null || true
  kubectl delete pod securerag-test-forbidden-registry -n "${NAMESPACE}" --ignore-not-found --wait=true --timeout=30s 2>/dev/null || true
}
trap cleanup EXIT

# Ensure namespace exists
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "--- Test 1: Positive - Signed image (should pass) ---"
cat <<'EOF' | kubectl apply --dry-run=server -f - 2>&1 && echo "[PASS] Signed image accepted." && PASS=$((PASS + 1)) || { echo "[FAIL] Signed image rejected unexpectedly." && FAIL=$((FAIL + 1)); }
apiVersion: v1
kind: Pod
metadata:
  name: securerag-test-signed
  namespace: securerag-hub
spec:
  containers:
    - name: app
      image: ghcr.io/YassinoMed/securerag-hub-app:v1.0.0
      imagePullPolicy: Always
EOF

echo ""
echo "--- Test 2: Negative - Unsigned image (should be rejected) ---"
cat <<'EOF' | kubectl apply --dry-run=server -f - 2>&1 | grep -q "denied" && echo "[PASS] Unsigned image rejected." && PASS=$((PASS + 1)) || { echo "[FAIL] Unsigned image was not rejected." && FAIL=$((FAIL + 1)); }
apiVersion: v1
kind: Pod
metadata:
  name: securerag-test-unsigned
  namespace: securerag-hub
spec:
  containers:
    - name: app
      image: ghcr.io/YassinoMed/securerag-hub-unsigned:latest
      imagePullPolicy: Always
EOF

echo ""
echo "--- Test 3: Negative - No SBOM attestation (should be rejected) ---"
cat <<'EOF' | kubectl apply --dry-run=server -f - 2>&1 | grep -q "denied" && echo "[PASS] No-SBOM image rejected." && PASS=$((PASS + 1)) || { echo "[FAIL] No-SBOM image was not rejected." && FAIL=$((FAIL + 1)); }
apiVersion: v1
kind: Pod
metadata:
  name: securerag-test-nosbom
  namespace: securerag-hub
spec:
  containers:
    - name: app
      image: ghcr.io/YassinoMed/securerag-hub-worker:v1.0.0
      imagePullPolicy: Always
EOF

echo ""
echo "--- Test 4: Negative - Latest tag (should be rejected) ---"
cat <<'EOF' | kubectl apply --dry-run=server -f - 2>&1 | grep -q "denied" && echo "[PASS] Latest tag rejected." && PASS=$((PASS + 1)) || { echo "[FAIL] Latest tag was not rejected." && FAIL=$((FAIL + 1)); }
apiVersion: v1
kind: Pod
metadata:
  name: securerag-test-latest
  namespace: securerag-hub
spec:
  containers:
    - name: app
      image: ghcr.io/YassinoMed/securerag-hub-app:latest
      imagePullPolicy: Always
EOF

echo ""
echo "--- Test 5: Negative - Forbidden registry (should be rejected) ---"
cat <<'EOF' | kubectl apply --dry-run=server -f - 2>&1 | grep -q "denied" && echo "[PASS] Forbidden registry rejected." && PASS=$((PASS + 1)) || { echo "[FAIL] Forbidden registry was not rejected." && FAIL=$((FAIL + 1)); }
apiVersion: v1
kind: Pod
metadata:
  name: securerag-test-forbidden-registry
  namespace: securerag-hub
spec:
  containers:
    - name: app
      image: docker.io/unauthorized/securerag-hub-app:v1.0.0
      imagePullPolicy: Always
EOF

echo ""
echo "--- Test 6: Negative - IPP not Always (should be rejected) ---"
cat <<'EOF' | kubectl apply --dry-run=server -f - 2>&1 | grep -q "denied" && echo "[PASS] Non-Always pull policy rejected." && PASS=$((PASS + 1)) || { echo "[FAIL] Non-Always pull policy was not rejected." && FAIL=$((FAIL + 1)); }
apiVersion: v1
kind: Pod
metadata:
  name: securerag-test-ipp
  namespace: securerag-hub
spec:
  containers:
    - name: app
      image: ghcr.io/YassinoMed/securerag-hub-app:v1.0.0
      imagePullPolicy: IfNotPresent
EOF

echo ""
echo "=========================================="
echo "  Résultat: PASS=${PASS}/6 FAIL=${FAIL}/6"
echo "=========================================="

if [[ "${FAIL}" -gt 0 ]]; then
  echo "[FAIL] ${FAIL} test(s) ont échoué."
  exit 1
else
  echo "[PASS] Tous les tests sont réussis."
fi
