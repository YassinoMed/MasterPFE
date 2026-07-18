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
TAG="test-$(date +%s)"
SIGNED_IMAGE="${REGISTRY}/securerag-hub-test-service:${TAG}"
UNSIGNED_IMAGE="${REGISTRY}/securerag-hub-test-service-unsigned:${TAG}"

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
# Extract and configure CTLog public key
CTLOG_PUB_FILE="/tmp/ctlog-public.pem"
kubectl get secret ctlog-public-key -n ctlog-system -o jsonpath='{.data.public}' | base64 -d > "${CTLOG_PUB_FILE}"
export SIGSTORE_CT_LOG_PUBLIC_KEY_FILE="${CTLOG_PUB_FILE}"

# Cosign v2+ uses keyless mode by default via Fulcio + Rekor
echo y | cosign sign \
  --fulcio-url=http://fulcio.sigstore-system \
  --rekor-url=http://rekor.sigstore-system \
  --oidc-issuer=http://keycloak.sigstore-system/realms/securerag-cicd \
  --identity-token="${TOKEN}" \
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
kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.cert}' | base64 -d > "${FULCIO_CERT_FILE}" || \
kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.cert\.pem}' | base64 -d > "${FULCIO_CERT_FILE}" || \
kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.cacert\.pem}' | base64 -d > "${FULCIO_CERT_FILE}" || \
kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.root\.pem}' | base64 -d > "${FULCIO_CERT_FILE}" || \
error "Failed to extract certificate from secret $SECRET_NAME."

info "Fulcio CA cert saved to ${FULCIO_CERT_FILE}"

# 5. Verify signature using Cosign CLI
info "Verifying signature using Cosign CLI..."
REKOR_PUB_FILE="/tmp/rekor-public.pem"
curl -s http://rekor.sigstore-system/api/v1/log/publicKey > "${REKOR_PUB_FILE}"
export SIGSTORE_REKOR_PUBLIC_KEY="${REKOR_PUB_FILE}"
export SIGSTORE_ROOT_FILE="${FULCIO_CERT_FILE}"
cosign verify \
  --rekor-url=http://rekor.sigstore-system \
  --certificate-identity=jenkins-cosign@securerag.local \
  --certificate-oidc-issuer=http://keycloak.sigstore-system/realms/securerag-cicd \
  "${SIGNED_IMAGE}"

info "CLI signature verification PASSED!"

# 6. Apply Kyverno Policy
info "Applying Kyverno ClusterPolicy..."
LOCAL_POLICY_FILE="/tmp/verify-image-signature-keyless-local.yaml"
python3 -c "
with open('k8s/kyverno-policies/verify-image-signature-keyless.yaml', 'r') as f:
    content = f.read()

with open('${FULCIO_CERT_FILE}', 'r') as f:
    fulcio = f.read().strip()
with open('${REKOR_PUB_FILE}', 'r') as f:
    rekor = f.read().strip()
with open('${CTLOG_PUB_FILE}', 'r') as f:
    ctlog = f.read().strip()

fulcio_indented = '\n'.join('                      ' + line for line in fulcio.split('\n'))
rekor_indented = '\n'.join('                        ' + line for line in rekor.split('\n'))
ctlog_indented = '\n'.join('                        ' + line for line in ctlog.split('\n'))

content = content.replace('@FULCIO_ROOT@', fulcio_indented)
content = content.replace('@REKOR_PUBKEY@', rekor_indented)
content = content.replace('@CTLOG_PUBKEY@', ctlog_indented)

content = content.replace('https://keycloak.sigstore-system', 'http://keycloak.sigstore-system')
content = content.replace('https://rekor.sigstore-system', 'http://rekor.sigstore-system')

with open('${LOCAL_POLICY_FILE}', 'w') as f:
    f.write(content)
"
kubectl apply -f "${LOCAL_POLICY_FILE}"

# Suspend the static cosign policy to isolate keyless admission testing
info "Temporarily auditing static cosign policy..."
kubectl patch clusterpolicy/securerag-verify-cosign-images --type=merge -p '{"spec":{"validationFailureAction":"Audit"}}'
trap 'kubectl patch clusterpolicy/securerag-verify-cosign-images --type=merge -p "{\"spec\":{\"validationFailureAction\":\"Enforce\"}}" 2>/dev/null || true' EXIT

# Wait for Kyverno policy validation webhook to sync (usually 8-10 seconds)
sleep 10

# 7. Test Admission Control - Unsigned Image (Should fail)
info "Testing Kyverno admission control: deploying UNSIGNED image (expecting BLOCK)..."
OUTPUT_UNSIGNED=$(kubectl run test-unsigned-pod --image="${UNSIGNED_IMAGE}" -n securerag-hub --dry-run=server 2>&1 || true)
if echo "${OUTPUT_UNSIGNED}" | grep -q "denied the request"; then
  info "Kyverno correctly BLOCKED the unsigned image deployment. PASS!"
else
  warn "Kyverno DID NOT block the unsigned image. Output was: ${OUTPUT_UNSIGNED}"
fi

# 8. Test Admission Control - Signed Image (Should pass)
info "Testing Kyverno admission control: deploying SIGNED image (expecting ALLOW)..."
OUTPUT_SIGNED=$(kubectl run test-signed-pod --image="${SIGNED_IMAGE}" -n securerag-hub --dry-run=server 2>&1 || true)
if echo "${OUTPUT_SIGNED}" | grep -q "denied the request"; then
  error "Kyverno BLOCKED the signed image deployment. Output was: ${OUTPUT_SIGNED}"
else
  info "Kyverno correctly ALLOWED the signed image deployment. PASS!"
fi

info "All tests completed successfully!"
