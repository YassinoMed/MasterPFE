// vars/cosignVerify.groovy — Shared Library: Cosign keyless verification
// SecureRAG Hub — Jenkins Shared Library
//
// Usage:
//   cosignVerify(
//     registryHost: 'ghcr.io',
//     imagePrefix: 'securerag-hub',
//     imageTag: 'latest',
//     identity: 'https://github.com/YassinoMed/MasterPFE/*',
//     issuer: 'https://token.actions.githubusercontent.com'
//   )

def call(Map params = [:]) {
  def registryHost = params.get('registryHost', 'ghcr.io')
  def imagePrefix = params.get('imagePrefix', 'securerag-hub')
  def imageTag = params.get('imageTag', 'latest')
  def identity = params.get('identity', 'https://github.com/YassinoMed/MasterPFE/*')
  def issuer = params.get('issuer', 'https://token.actions.githubusercontent.com')

  def services = ['portal-web', 'auth-users', 'chatbot-manager', 'conversation-service', 'audit-security-service']

  echo "[COSIGN] Verifying ${services.size()} images (keyless mode)..."

  def failures = 0
  def successes = 0

  services.each { service ->
    def image = "${registryHost}/${imagePrefix}-${service}:${imageTag}"
    echo "[COSIGN] Verifying ${image}..."

    def exitCode = sh(
      script: """
        cosign verify ${image} \
          --certificate-identity-regexp="${identity}" \
          --certificate-oidc-issuer-regexp="${issuer}" \
          --rekor-url=https://rekor.sigstore.dev \
          -o json 2>/dev/null
      """,
      returnStatus: true
    )

    if (exitCode == 0) {
      echo "[COSIGN] ✅ ${service} verified"
      successes++
    } else {
      echo "[COSIGN] ❌ ${service} verification FAILED"
      failures++
    }
  }

  echo "[COSIGN] ${successes} verified, ${failures} failed"

  if (failures > 0) {
    error "COSIGN VERIFICATION FAILED: ${failures} image(s) not verified"
  }

  return true
}
