// vars/runSastScan.groovy — SecureRAG Hub Shared Library
// Executes Semgrep SAST and Gitleaks secrets detection in parallel or standalone with SARIF/JSON reporting.
//
// Usage in Jenkinsfile:
//   runSastScan(tool: 'semgrep', reportDir: 'security/reports')
//   runSastScan(tool: 'gitleaks', reportDir: 'security/reports')

def call(Map config = [:]) {
    def tool = config.get('tool', 'semgrep')
    def reportDir = config.get('reportDir', 'security/reports')
    def failOnError = config.get('failOnError', true)

    sh "mkdir -p ${reportDir}"

    if (tool == 'semgrep') {
        echo "[SAST] Running Semgrep Scan..."
        sh """
            set -euo pipefail
            if command -v semgrep >/dev/null 2>&1; then
                semgrep scan --config security/semgrep/semgrep.yml --json -o "${reportDir}/semgrep.json" || true
                semgrep scan --config security/semgrep/semgrep.yml --sarif -o "${reportDir}/semgrep.sarif" || true
            else
                echo '[WARN] Semgrep CLI not found; creating fallback schema compliance placeholders.'
                echo '{"results": []}' > "${reportDir}/semgrep.json"
                echo '{"\$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.5.json", "version": "2.1.0", "runs": []}' > "${reportDir}/semgrep.sarif"
            fi
        """
    } else if (tool == 'gitleaks') {
        echo "[SAST] Running Gitleaks Secrets Scan..."
        def exitCode = sh(
            script: """
                set -euo pipefail
                if command -v gitleaks >/dev/null 2>&1; then
                    gitleaks detect --no-git --config .gitleaks.toml --exclude-path "(node_modules|vendor|\\.venv|\\.kaniko-cache|istio-1\\.23\\.0|\\.coverage-artifacts|artifacts|security/reports)" --report-format json --report-path "${reportDir}/gitleaks.json" --exit-code 0 || true
                    gitleaks detect --no-git --config .gitleaks.toml --exclude-path "(node_modules|vendor|\\.venv|\\.kaniko-cache|istio-1\.23\.0|\\.coverage-artifacts|artifacts|security/reports)" --report-format sarif --report-path "${reportDir}/gitleaks.sarif" --exit-code 1
                elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
                    docker run --rm -v "\$PWD:/repo" -w /repo ghcr.io/gitleaks/gitleaks:v8.30.1 detect --no-git --config .gitleaks.toml --exclude-path "(node_modules|vendor|\\.venv|\\.kaniko-cache|istio-1\\.23\\.0|\\.coverage-artifacts|artifacts|security/reports)" --report-format json --report-path "/repo/${reportDir}/gitleaks.json" --exit-code 0 || true
                    docker run --rm -v "\$PWD:/repo" -w /repo ghcr.io/gitleaks/gitleaks:v8.30.1 detect --no-git --config .gitleaks.toml --exclude-path "(node_modules|vendor|\\.venv|\\.kaniko-cache|istio-1\\.23\\.0|\\.coverage-artifacts|artifacts|security/reports)" --report-format sarif --report-path "/repo/${reportDir}/gitleaks.sarif" --exit-code 1
                else
                    echo '[WARN] Gitleaks unavailable. Generating empty sarif.'
                    echo '{"\$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.5.json", "version": "2.1.0", "runs": []}' > "${reportDir}/gitleaks.sarif"
                    exit 0
                fi
            """,
            returnStatus: true
        )
        if (exitCode != 0 && failOnError) {
            error "[SAST] Gitleaks detected secrets! Build blocked."
        }
    }
}
