// vars/checkovScan.groovy — Shared Library: Checkov IaC scanning
// SecureRAG Hub — Jenkins Shared Library
//
// Usage:
//   checkovScan(
//     directories: ['infra/k8s/', 'infra/helm/'],
//     reportDir: 'security/reports'
//   )

def call(Map params = [:]) {
  def directories = params.get('directories', ['infra/k8s/', 'infra/helm/', 'platform/', 'services-laravel/'])
  def reportDir = params.get('reportDir', 'security/reports')

  echo "[CHECKOV] Scanning ${directories.size()} directories..."

  directories.each { dir ->
    def safeName = dir.replaceAll('[^a-zA-Z0-9]', '_')
    def reportFile = "${reportDir}/checkov-${safeName}.xml"

    sh """
      mkdir -p ${reportDir}
      checkov -d ${dir} \
        --config-file security/checkov-config.yaml \
        --hard-fail-on CRITICAL \
        --soft-fail-on HIGH \
        -o junitxml > ${reportFile}
    """
    echo "[CHECKOV] ${dir} → ${reportFile}"
  }

  echo "[CHECKOV] All scans complete"
  return true
}
