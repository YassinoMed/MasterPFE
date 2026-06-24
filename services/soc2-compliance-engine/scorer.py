def calculate_score(k8s_data):
    base_score = 100
    risks = []
    
    # 1. Evaluate Kyverno Policies
    for report in k8s_data.get("kyverno_policies", []):
        results = report.get("results", [])
        for res in results:
            if res.get("result") == "fail":
                severity = res.get("severity", "medium")
                risks.append({
                    "source": "kyverno",
                    "severity": severity,
                    "description": res.get("message", "Policy violation")
                })
                if severity == "high":
                    base_score -= 5
                elif severity == "medium":
                    base_score -= 2
                else:
                    base_score -= 1
                    
    # 2. Evaluate Trivy Vulnerabilities
    for report in k8s_data.get("trivy_vulnerabilities", []):
        vulns = report.get("report", {}).get("vulnerabilities", [])
        for v in vulns:
            severity = v.get("severity", "UNKNOWN").lower()
            if severity in ["critical", "high"]:
                risks.append({
                    "source": "trivy",
                    "severity": severity,
                    "description": f"Vulnerability {v.get('vulnerabilityID')} in {v.get('resource')}"
                })
                if severity == "critical":
                    base_score -= 10
                elif severity == "high":
                    base_score -= 5

    # Ensure score doesn't drop below 0
    final_score = max(0, base_score)
    
    return final_score, risks
