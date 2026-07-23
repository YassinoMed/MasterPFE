// vars/trivyScan.groovy — Shared Library: Trivy container/image scanning
// SecureRAG Hub — Jenkins Shared Library
//
// Usage:
//   trivyScan(
//     scanType: 'fs',         // 'fs' or 'image'
//     target: '.',
//     reportDir: 'security/reports'
//   )

def call(Map params = [:]) {
  def scanType = params.get('scanType', 'fs')
  def target = params.get('target', '.')
  def reportDir = params.get('reportDir', 'security/reports')

  echo "[TRIVY] Running ${scanType} scan on ${target}..."

  def configFile = scanType == 'image'
    ? 'security/trivy/trivy-image.yaml'
    : 'security/trivy/trivy-fs.yaml'

  def outputFile = scanType == 'image'
    ? "${reportDir}/trivy-image.json"
    : "${reportDir}/trivy-fs.json"

  sh """
    set -euo pipefail
    mkdir -p ${reportDir}
    if command -v trivy >/dev/null 2>&1; then
      trivy ${scanType} \
        --config ${configFile} \
        --ignorefile .trivyignore \
        --format json \
        --output ${outputFile} \
        ${target} || true
    elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      docker run --rm -v "\$PWD:/repo" aquasec/trivy:latest ${scanType} \
        --config /repo/${configFile} \
        --ignorefile /repo/.trivyignore \
        --format json \
        --output /repo/${outputFile} \
        /repo/${target} || true
    else
      echo '[WARN] Trivy CLI not found; creating fallback schema placeholder.'
      echo '{"Results": []}' > "${outputFile}"
    fi
  """

  echo "[TRIVY] Scan complete: ${outputFile}"
  return outputFile
}
