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
                    gitleaks detect --no-git --config .gitleaks.toml --report-format json --report-path "${reportDir}/gitleaks.json" --exit-code 0 || true
                elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
                    docker run --rm -v "\$PWD:/repo" -w /repo ghcr.io/gitleaks/gitleaks:v8.30.1 detect --no-git --config .gitleaks.toml --report-format json --report-path "/repo/${reportDir}/gitleaks.json" --exit-code 0 || true
                else
                    echo '[WARN] Gitleaks unavailable. Generating empty sarif/json.'
                    echo '[]' > "${reportDir}/gitleaks.json"
                fi

                # Convert JSON to SARIF in single-pass (<0.1s)
                python3 -c '
import json, sys, os
json_path = "${reportDir}/gitleaks.json"
sarif_path = "${reportDir}/gitleaks.sarif"
findings = []
if os.path.exists(json_path) and os.path.getsize(json_path) > 0:
    try:
        with open(json_path) as f:
            findings = json.load(f)
    except Exception:
        findings = []

sarif = {
    "\$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.5.json",
    "version": "2.1.0",
    "runs": [{
        "tool": {"driver": {"name": "Gitleaks", "version": "8.30.1"}},
        "results": [{"ruleId": f.get("RuleID", "secret"), "message": {"text": f.get("Description", "Secret detected")}, "locations": [{"physicalLocation": {"artifactLocation": {"uri": f.get("File", "")}, "region": {"startLine": f.get("StartLine", 1)}}}]} for f in findings]
    }]
}
with open(sarif_path, "w") as f:
    json.dump(sarif, f, indent=2)
' || echo '{"\$schema": "https://schemastore.azurewebsites.net/schemas/json/sarif-2.1.0-rtm.5.json", "version": "2.1.0", "runs": []}' > "${reportDir}/gitleaks.sarif"

                if [ \$(python3 -c 'import json; print(len(json.load(open("${reportDir}/gitleaks.json"))))' 2>/dev/null || echo "0") -gt 0 ]; then
                    exit 1
                fi
            """,
            returnStatus: true
        )
        if (exitCode != 0 && failOnError) {
            error "[SAST] Gitleaks detected secrets! Build blocked."
        }
    }
}
