#!/bin/bash
set -euo pipefail

# Required Envs:
# REGISTRY_HOST
# IMAGE_PREFIX
# IMAGE_TAG
# COSIGN_KEY

echo "[INFO] Generating and Attesting SLSA Provenance..."

for service in auth-users chatbot-manager conversation-service audit-security-service portal-web; do
    IMAGE_REF="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}:${IMAGE_TAG}"
    
    # Get image digest
    echo "[INFO] Fetching digest for ${IMAGE_REF}..."
    DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE_REF}" | awk -F'@' '{print $2}' || true)
    
    if [ -z "$DIGEST" ]; then
        echo "[WARN] Could not determine digest for ${IMAGE_REF}. Falling back to tag..."
        TARGET_REF="${IMAGE_REF}"
    else
        TARGET_REF="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}@${DIGEST}"
    fi

    echo "[INFO] Generating SLSA Provenance for ${TARGET_REF}..."
    
    # Create SLSA v1.0 Provenance Predicate
    PREDICATE_FILE="artifacts/release/${service}-slsa-predicate.json"
    cat <<EOF > "${PREDICATE_FILE}"
{
  "builder": {
    "id": "${BUILD_URL:-https://jenkins.securerag.local/job/securerag-hub/}"
  },
  "buildType": "https://jenkins.io/pipeline/v1",
  "invocation": {
    "configSource": {
      "uri": "${GIT_URL:-https://github.com/securerag/securerag-hub}",
      "digest": {
        "sha1": "${GIT_COMMIT:-unknown}"
      },
      "entryPoint": "Jenkinsfile"
    },
    "environment": {
      "buildNumber": "${BUILD_NUMBER:-unknown}",
      "jobName": "${JOB_NAME:-unknown}"
    }
  },
  "metadata": {
    "buildStartedOn": "${DR_START_TIME:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}",
    "completeness": {
      "parameters": true,
      "environment": true,
      "materials": true
    },
    "reproducible": false
  }
}
EOF

    echo "[INFO] Attesting image with Cosign..."
    cosign attest \
        --yes \
        --key "${COSIGN_KEY}" \
        --type slsaprovenance \
        --predicate "${PREDICATE_FILE}" \
        "${TARGET_REF}"

    echo "[INFO] SLSA provenance successfully attached to ${TARGET_REF}"
done
