#!/usr/bin/env bash
# security/tests/test-keyless-signing.sh
# End-to-end validation script for keyless OIDC signing via local Sigstore.

set -euo pipefail

info() { printf '\e[34m[INFO]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[WARN]\e[0m %s\n' "$*" >&2; }
error() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; exit 1; }

# Ensure required commands exist
command -v cosign &>/dev/null || error "cosign is not installed on the host. Please run the deploy script first."
command -v jq &>/dev/null || error "jq is required but not installed."
command -v kubectl &>/dev/null || error "kubectl is required but not installed."
command -v docker &>/dev/null || error "docker is required but not installed."

# Configuration
REGISTRY="localhost:5001"
SIGNED_IMAGE="${REGISTRY}/securerag-hub-test-service:latest"
UNSIGNED_IMAGE="${REGISTRY}/securerag-hub-test-service-unsigned:latest"

# 1. Build and push test images
info "Building and pushing test images to ${REGISTRY}..."
docker pull alpine:latest
docker tag alpine:latest "${SIGNED_IMAGE}"
docker tag alpine:latest "${UNSIGNED_IMAGE}"
docker push "${SIGNED_IMAGE}"
docker push "${UNSIGNED_IMAGE}"

# 2. Retrieve OIDC Token from Keycloak
info "Retrieving OIDC ID Token from Keycloak..."
TOKEN=$(curl -s -X POST \
  http://keycloak.sigstore-system/realms/securerag-cicd/protocol/openid-connect/token \
  -d "client_id=jenkins-cosign&client_secret=jenkins-cosign-secret&grant_type=client_credentials" \
  | jq -r .access_token)

if [ -z "${TOKEN}" ] || [ "${TOKEN}" = "null" ]; then
  error "Failed to retrieve OIDC access token from Keycloak."
fi
info "OIDC token retrieved successfully."

# 3. Sign image keyless via local Fulcio & Rekor
info "Signing image keyless..."
export COSIGN_EXPERIMENTAL=1
cosign sign \
  --fulcio-url=http://fulcio.sigstore-system \
  --rekor-url=http://rekor.sigstore-system \
  --oidc-issuer=http://keycloak.sigstore-system/realms/securerag-cicd \
  --identity-token="${TOKEN}" \
  --allow-insecure-registry \
  --yes \
  "${SIGNED_IMAGE}"

info "Image signed successfully."

# 4. Extract Fulcio CA certificate
info "Extracting Fulcio CA certificate..."
SECRET_NAME=$(kubectl get secrets -n sigstore-system -o name | grep fulcio | head -n 1 | cut -d/ -f2 || echo "")
if [ -z "$SECRET_NAME" ]; then
  error "Could not find Fulcio secret in sigstore-system namespace."
fi

FULCIO_CERT_FILE="/tmp/fulcio-root.pem"
kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.cert\.pem}' | base64 -d > "${FULCIO_CERT_FILE}" || \
kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.cacert\.pem}' | base64 -d > "${FULCIO_CERT_FILE}" || \
kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.root\.pem}' | base64 -d > "${FULCIO_CERT_FILE}" || \
error "Failed to extract certificate from secret $SECRET_NAME."

info "Fulcio CA cert saved to ${FULCIO_CERT_FILE}"

# 5. Verify signature using Cosign CLI
info "Verifying signature using Cosign CLI..."
export SIGSTORE_ROOT_FILE="${FULCIO_CERT_FILE}"
cosign verify \
  --rekor-url=http://rekor.sigstore-system \
  --certificate-identity=jenkins-cosign@securerag.local \
  --certificate-oidc-issuer=http://keycloak.sigstore-system/realms/securerag-cicd \
  --allow-insecure-registry \
  "${SIGNED_IMAGE}"

info "CLI signature verification PASSED!"

# 6. Apply Kyverno Policy
info "Applying Kyverno ClusterPolicy..."
kubectl apply -f k8s/kyverno-policies/verify-image-signature-keyless.yaml

# Wait for Kyverno policy validation webhook to sync (usually few seconds)
sleep 3

# 7. Test Admission Control - Unsigned Image (Should fail)
info "Testing Kyverno admission control: deploying UNSIGNED image (expecting BLOCK)..."
if kubectl run test-unsigned-pod --image="${UNSIGNED_IMAGE}" -n securerag-hub --dry-run=server 2>&1 | grep -q "denied the request"; then
  info "Kyverno correctly BLOCKED the unsigned image deployment. PASS!"
else
  warn "Kyverno DID NOT block the unsigned image. Check policy installation."
fi

# 8. Test Admission Control - Signed Image (Should pass)
info "Testing Kyverno admission control: deploying SIGNED image (expecting ALLOW)..."
if kubectl run test-signed-pod --image="${SIGNED_IMAGE}" -n securerag-hub --dry-run=server &>/dev/null; then
  info "Kyverno correctly ALLOWED the signed image deployment. PASS!"
else
  error "Kyverno BLOCKED the signed image deployment. Check policy configuration."
fi

info "All tests completed successfully!"
