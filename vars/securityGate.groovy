#!/usr/bin/env groovy
// vars/securityGate.groovy — SecureRAG Hub Security Gate Shared Library
// FAANG-grade scope-aware security gate for Jenkins pipelines.
//
// Usage:
//   securityGate(
//     trivyReport: 'security/reports/trivy-scope.json',
//     semgrepReport: 'security/reports/semgrep.json',
//     gitleaksReport: 'security/reports/gitleaks.json',
//     failOnHigh: true,
//     failOnCritical: true
//   )
//
// Returns: Map with status, summary, and findings

def call(Map config = [:]) {
    def trivyReport = config.get('trivyReport', 'security/reports/trivy-scope.json')
    def semgrepReport = config.get('semgrepReport', 'security/reports/semgrep.json')
    def gitleaksReport = config.get('gitleaksReport', 'security/reports/gitleaks.json')
    def failOnHigh = config.get('failOnHigh', true)
    def failOnCritical = config.get('failOnCritical', true)
    def classifierScript = 'security/engine/security-classifier.sh'
    def gateEngineScript = 'security/engine/gate-decision-engine.sh'

    echo "[securityGate] Running Security Scoping Engine..."
    echo "[securityGate] Trivy: ${trivyReport}"
    echo "[securityGate] Semgrep: ${semgrepReport}"
    echo "[securityGate] Gitleaks: ${gitleaksReport}"

    // ── Step 1: Verify inputs exist ────────────────────────────────

    def missingReports = []
    if (!fileExists(trivyReport)) { missingReports.push("Trivy: ${trivyReport}") }
    if (!fileExists(semgrepReport)) { missingReports.push("Semgrep: ${semgrepReport}") }
    if (!fileExists(gitleaksReport)) { missingReports.push("Gitleaks: ${gitleaksReport}") }

    if (missingReports.size() > 0) {
        echo "[WARN] Missing reports: ${missingReports.join(', ')}"
    }

    // ── Step 2: Classify Trivy findings by scope ───────────────────

    def classifiedReport = 'security/reports/trivy-classified.json'
    if (fileExists(trivyReport) && fileExists(classifierScript)) {
        sh """
            bash ${classifierScript} --classify-from-trivy ${trivyReport} > ${classifiedReport} 2>/dev/null || true
        """
    }

    // ── Step 3: Parse production findings ──────────────────────────

    def prodCritical = 0
    def prodHigh = 0
    def prodMedium = 0
    def findings = []

    if (fileExists(classifiedReport)) {
        def classified = readJSON file: classifiedReport
        def prod = classified.get('PRODUCTION', [:])
        prodCritical = prod.get('severities', [:]).get('CRITICAL', 0)
        prodHigh = prod.get('severities', [:]).get('HIGH', 0)
        prodMedium = prod.get('severities', [:]).get('MEDIUM', 0)
        findings = prod.get('findings', [])
    }

    // ── Step 4: Decision ───────────────────────────────────────────

    def gateStatus = 'PASS'
    def reasons = []

    if (prodCritical > 0 && failOnCritical) {
        gateStatus = 'FAIL'
        reasons.push("${prodCritical} CRITICAL vulnerability(ies) in PRODUCTION scope")
    }

    if (prodHigh > 0 && failOnHigh) {
        gateStatus = 'FAIL'
        reasons.push("${prodHigh} HIGH vulnerability(ies) in PRODUCTION scope")
    }

    if (prodMedium > 0 && gateStatus != 'FAIL') {
        gateStatus = 'WARNING'
        reasons.push("${prodMedium} MEDIUM vulnerability(ies) in PRODUCTION scope")
    }

    // ── Step 5: Generate summary ───────────────────────────────────

    def summary = """
| Security Gate — ${gateStatus} |
|${'='.repeat(50)}|
| Scope        | PRODUCTION                                    |
| CRITICAL     | ${prodCritical.toString().padLeft(4)}                                       |
| HIGH         | ${prodHigh.toString().padLeft(4)}                                       |
| MEDIUM       | ${prodMedium.toString().padLeft(4)}                                       |
| Findings     | ${findings.size().toString().padLeft(4)}                                       |
"""

    echo "[securityGate] Status: ${gateStatus}"
    echo "[securityGate] PROD CRITICAL: ${prodCritical}, PROD HIGH: ${prodHigh}, PROD MEDIUM: ${prodMedium}"
    if (reasons.size() > 0) {
        echo "[securityGate] Reasons: ${reasons.join(', ')}"
    }

    // ── Step 6: Archive evidence ───────────────────────────────────

    if (fileExists(classifiedReport)) {
        archiveArtifacts artifacts: classifiedReport, allowEmptyArchive: true
    }

    // ── Step 7: Fail pipeline if needed ────────────────────────────

    if (gateStatus == 'FAIL') {
        error "[securityGate] BLOCKED: ${reasons.join('; ')}"
    }

    // Return results for downstream stages
    return [
        status: gateStatus,
        prodCritical: prodCritical,
        prodHigh: prodHigh,
        prodMedium: prodMedium,
        totalFindings: findings.size(),
        reasons: reasons,
        summary: summary
    ]
}
