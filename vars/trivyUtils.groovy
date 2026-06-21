// vars/trivyUtils.groovy

/**
 * Parses a Trivy JSON report and returns a map of vulnerability counts by severity.
 * Handles missing or malformed files gracefully.
 */
def parseTrivyReport(String filePath) {
    def counts = [CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0]
    
    if (!fileExists(filePath)) {
        echo "[WARN] Trivy report file not found at: ${filePath}"
        return counts
    }
    
    try {
        def report = readJSON file: filePath
        if (report && report.Results) {
            for (result in report.Results) {
                if (result.Vulnerabilities) {
                    for (vuln in result.Vulnerabilities) {
                        def severity = vuln.Severity ? vuln.Severity.toUpperCase() : ""
                        if (counts.containsKey(severity)) {
                            counts[severity] = counts[severity] + 1
                        }
                    }
                }
            }
        }
        echo "[INFO] Successfully parsed Trivy report. Counts: ${counts}"
    } catch (Exception e) {
        echo "[ERROR] Failed to parse Trivy JSON report at ${filePath}: ${e.getMessage()}"
    }
    
    return counts
}
