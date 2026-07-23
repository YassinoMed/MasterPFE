// vars/buildDockerImage.groovy — SecureRAG Hub Shared Library
// High-performance Docker BuildKit builder with registry caching and context isolation.
//
// Usage in Jenkinsfile:
//   buildDockerImage(
//     componentName: 'auth-users',
//     contextDir: 'services-laravel/auth-users-service',
//     dockerfile: 'services-laravel/auth-users-service/Dockerfile',
//     registryHost: 'localhost:5001',
//     imagePrefix: 'securerag-hub',
//     imageTag: 'dev'
//   )

def call(Map config = [:]) {
    def componentName = config.get('componentName')
    def contextDir = config.get('contextDir')
    def dockerfile = config.get('dockerfile', "${contextDir}/Dockerfile")
    def registryHost = config.get('registryHost', env.REGISTRY_HOST ?: 'localhost:5001')
    def imagePrefix = config.get('imagePrefix', env.IMAGE_PREFIX ?: 'securerag-hub')
    def imageTag = config.get('imageTag', env.IMAGE_TAG ?: 'dev')

    if (!componentName || !contextDir) {
        error "[buildDockerImage] Missing required arguments 'componentName' or 'contextDir'"
    }

    def targetImage = "${registryHost}/${imagePrefix}-${componentName}:${imageTag}"
    def cacheImage = "${registryHost}/${imagePrefix}-${componentName}:build-cache"

    echo "[buildDockerImage] Building ${targetImage} from ${dockerfile} (Context: ${contextDir})..."

    sh """
        set -euo pipefail
        export DOCKER_BUILDKIT=1
        export BUILDKIT_PROGRESS=plain

        if [ ! -f "${dockerfile}" ]; then
            echo "[ERROR] Dockerfile not found at ${dockerfile}"
            exit 1
        fi

        # Scope context to contextDir to avoid sending full root repo payload to daemon
        docker build \
          --progress=plain \
          --build-arg BUILDKIT_INLINE_CACHE=1 \
          --cache-from "${cacheImage}" \
          --cache-from "${targetImage}" \
          -t "${targetImage}" \
          -f "${dockerfile}" \
          "${contextDir}" || {
            echo "[WARN] BuildKit cached build failed. Retrying without cache import..."
            docker build --progress=plain -t "${targetImage}" -f "${dockerfile}" "${contextDir}"
          }
    """

    echo "[buildDockerImage] Successfully built ${targetImage}"
    return targetImage
}
