#!/usr/bin/env groovy
// vars/performanceGate.groovy — SecureRAG Hub Performance Gate Shared Library
// ═══════════════════════════════════════════════════════════════════════════
// Evaluates k6 performance test results against quality gate thresholds.
// Fails the pipeline if thresholds are breached.
//
// Usage:
//   performanceGate(
//     reportDir: 'reports/k6',
//     p95Threshold: 200,
//     errorRateThreshold: 0.01,
//     availabilityThreshold: 99.0,
//     failOnBreach: true
//   )
//
// Returns: Map with status, metrics, and breaches

def call(Map config = [:]) {
    def reportDir = config.get('reportDir', 'reports/k6')
    def p95Threshold = config.get('p95Threshold', 200)
    def errorRateThreshold = config.get('errorRateThreshold', 0.01)
    def availabilityThreshold = config.get('availabilityThreshold', 99.0)
    def failOnBreach = config.get('failOnBreach', true)
    def testNames = config.get('testNames', 'smoke,load')

    echo "[performanceGate] ═══════════════════════════════════════════"
    echo "[performanceGate] Performance Quality Gate Evaluation"
    echo "[performanceGate]   Report dir:   ${reportDir}"
    echo "[performanceGate]   p95 gate:     < ${p95Threshold}ms"
    echo "[performanceGate]   Error gate:   < ${(errorRateThreshold * 100)}%"
    echo "[performanceGate]   Availability: > ${availabilityThreshold}%"
    echo "[performanceGate] ═══════════════════════════════════════════"

    // ── Step 1: Run the quality gate script ─────────────────────────
    def latestDir = ''
    try {
        latestDir = sh(
            script: "find ${reportDir} -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -1",
            returnStdout: true
        ).trim()
    } catch (Exception e) {
        echo "[performanceGate] WARNING: Could not find results directory: ${e.getMessage()}"
    }

    if (!latestDir || !fileExists(latestDir)) {
        echo "[performanceGate] WARNING: No results directory found in ${reportDir}"
        return [status: 'SKIP', reason: 'No results found']
    }

    echo "[performanceGate] Evaluating results from: ${latestDir}"

    def exitCode = sh(
        script: """
            P95_THRESHOLD_MS=${p95Threshold} \
            ERROR_RATE_THRESHOLD=${errorRateThreshold} \
            AVAILABILITY_THRESHOLD=${availabilityThreshold} \
            bash scripts/performance/performance-quality-gate.sh "${latestDir}"
        """,
        returnStatus: true
    )

    // ── Step 2: Parse the JSON result ───────────────────────────────
    def gateResult = [:]
    def resultFile = "${reportDir}/performance-gate-result.json"
    if (fileExists(resultFile)) {
        gateResult = readJSON file: resultFile
    }

    def gatePassed = gateResult.get('gate_passed', false)
    def gateStatus = gateResult.get('status', exitCode == 0 ? 'PASSED' : 'FAILED')
    def breaches = gateResult.get('breaches', [])

    // ── Step 3: Archive reports ─────────────────────────────────────
    archiveArtifacts allowEmptyArchive: true,
        artifacts: "${reportDir}/**"

    // Publish HTML reports if available
    def htmlFiles = findFiles(glob: "${latestDir}/*.html") ?: []
    if (htmlFiles.size() > 0) {
        publishHTML(target: [
            allowMissing: true,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: latestDir,
            reportFiles: '*.html',
            reportName: 'k6 Performance Reports'
        ])
    }

    // Also archive the gate report from the root reports dir
    archiveArtifacts allowEmptyArchive: true,
        artifacts: "${reportDir}/performance-gate-report.md,${reportDir}/performance-gate-result.json"

    // ── Step 4: Log summary ─────────────────────────────────────────
    echo "[performanceGate] ═══════════════════════════════════════════"
    echo "[performanceGate] RESULT: ${gateStatus}"
    if (gateResult.observed) {
        echo "[performanceGate]   Worst p95:       ${gateResult.observed.worst_p95_ms}ms"
        echo "[performanceGate]   Worst error:     ${gateResult.observed.worst_error_rate}"
        echo "[performanceGate]   Availability:    ${gateResult.observed.best_availability_pct}%"
        echo "[performanceGate]   Total requests:  ${gateResult.observed.total_requests}"
    }
    if (breaches) {
        echo "[performanceGate] Breaches:"
        breaches.each { echo "[performanceGate]   • ${it}" }
    }
    echo "[performanceGate] ═══════════════════════════════════════════"

    // ── Step 5: Fail pipeline if needed ──────────────────────────────
    if (!gatePassed && failOnBreach) {
        error "[performanceGate] BLOCKED: Performance quality gates not met. ${breaches.join('; ')}"
    }

    return [
        status: gateStatus,
        passed: gatePassed,
        breaches: breaches,
        observed: gateResult.get('observed', [:]),
        thresholds: [
            p95: p95Threshold,
            errorRate: errorRateThreshold,
            availability: availabilityThreshold
        ]
    ]
}
