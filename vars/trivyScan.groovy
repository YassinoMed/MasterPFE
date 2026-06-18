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
    mkdir -p ${reportDir}
    trivy ${scanType} \
      --config ${configFile} \
      --ignorefile .trivyignore \
      --format json \
      --output ${outputFile} \
      ${target}
  """

  echo "[TRIVY] Scan complete: ${outputFile}"
  return outputFile
}
