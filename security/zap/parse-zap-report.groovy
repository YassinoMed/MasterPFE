// security/zap/parse-zap-report.groovy
import groovy.json.JsonSlurper

def parseZapReport(String reportPath, int maxHighAllowed = 0, int maxCriticalAllowed = 0) {
    echo "[INFO] Parsing ZAP JSON report at ${reportPath}..."
    def file = new File(reportPath)
    if (!file.exists()) {
        echo "[ERROR] ZAP report file not found: ${reportPath}"
        return false
    }

    def jsonSlurper = new JsonSlurper()
    def report = jsonSlurper.parseText(file.text)
    
    int highCount = 0
    int criticalCount = 0
    int mediumCount = 0
    int lowCount = 0
    int infoCount = 0

    if (report.site) {
        report.site.each { site ->
            if (site.alerts) {
                site.alerts.each { alert ->
                    def riskcode = alert.riskcode ? alert.riskcode.toInteger() : 0
                    def riskdesc = alert.riskdesc ?: ""
                    
                    if (riskcode == 3 || riskdesc.contains("High")) {
                        highCount++
                    } else if (riskcode == 4 || riskdesc.contains("Critical")) {
                        criticalCount++
                    } else if (riskcode == 2 || riskdesc.contains("Medium")) {
                        mediumCount++
                    } else if (riskcode == 1 || riskdesc.contains("Low")) {
                        lowCount++
                    } else {
                        infoCount++
                    }
                }
            }
        }
    }

    echo "=== ZAP DAST Quality Gate Summary ==="
    echo "Critical: ${criticalCount} (Allowed: ${maxCriticalAllowed})"
    echo "High: ${highCount} (Allowed: ${maxHighAllowed})"
    echo "Medium: ${mediumCount}"
    echo "Low: ${lowCount}"
    echo "Info: ${infoCount}"

    if (highCount > maxHighAllowed || criticalCount > maxCriticalAllowed) {
        echo "[FAIL] ZAP Quality Gate failed: found ${highCount} High and ${criticalCount} Critical alerts."
        return false
    }
    
    echo "[PASS] ZAP Quality Gate passed."
    return true
}

return this
