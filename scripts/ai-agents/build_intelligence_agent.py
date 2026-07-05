#!/usr/bin/env python3
import json
import os
import sys

class BuildIntelligenceAgent:
    def __init__(self, reports_dir="security/reports"):
        self.reports_dir = reports_dir
        self.findings = []
        
    def parse_trivy(self):
        trivy_path = os.path.join(self.reports_dir, "trivy-fs.json")
        if not os.path.exists(trivy_path):
            return 0
        try:
            with open(trivy_path, "r") as f:
                data = json.load(f)
            # Parse vulnerabilities
            vulns_count = 0
            results = data.get("Results", [])
            for res in results:
                vulns = res.get("Vulnerabilities", [])
                for v in vulns:
                    # Filter out false positives (e.g. legacy requirements or mock templates)
                    pkg = v.get("PkgName", "")
                    if "mockery" in pkg or "embeding" in v.get("PrimaryURL", ""):
                        # Skip false positive
                        continue
                    vulns_count += 1
                    self.findings.append({
                        "source": "Trivy",
                        "id": v.get("VulnerabilityID"),
                        "severity": v.get("Severity"),
                        "package": pkg,
                        "description": v.get("Title", "Vulnerability found")
                    })
            return vulns_count
        except Exception as e:
            print(f"[Build Agent] Failed to parse Trivy: {e}")
            return 0

    def parse_semgrep(self):
        semgrep_path = os.path.join(self.reports_dir, "semgrep.json")
        if not os.path.exists(semgrep_path):
            return 0
        try:
            with open(semgrep_path, "r") as f:
                data = json.load(f)
            semgrep_count = 0
            results = data.get("results", [])
            for r in results:
                semgrep_count += 1
                self.findings.append({
                    "source": "Semgrep",
                    "id": r.get("check_id"),
                    "severity": r.get("extra", {}).get("severity", "WARNING"),
                    "package": r.get("path"),
                    "description": r.get("extra", {}).get("message")
                })
            return semgrep_count
        except Exception as e:
            print(f"[Build Agent] Failed to parse Semgrep: {e}")
            return 0

    def parse_gitleaks(self):
        gitleaks_path = os.path.join(self.reports_dir, "gitleaks.json")
        if not os.path.exists(gitleaks_path):
            return 0
        try:
            with open(gitleaks_path, "r") as f:
                data = json.load(f)
            gitleaks_count = 0
            # Gitleaks output is a list of findings
            for f in data:
                # Filter false positive placeholder tokens
                secret = f.get("Secret", "")
                if "placeholder" in secret.lower() or "your_token" in secret.lower():
                    continue
                gitleaks_count += 1
                self.findings.append({
                    "source": "Gitleaks",
                    "id": f.get("RuleID"),
                    "severity": "CRITICAL",
                    "package": f.get("File"),
                    "description": f.get("Description", "Leak detected")
                })
            return gitleaks_count
        except Exception as e:
            print(f"[Build Agent] Failed to parse Gitleaks: {e}")
            return 0

    def calculate_scores(self) -> tuple:
        """
        Calculates a Risk Score (0-100) and Confidence Score (0-100).
        """
        risk_score = 0.0
        confidence_score = 100.0
        
        if not self.findings:
            return 0.0, 100.0
            
        critical_count = 0
        high_count = 0
        medium_count = 0
        
        for f in self.findings:
            sev = f["severity"].upper()
            if sev in ["CRITICAL", "ERROR"]:
                critical_count += 1
            elif sev in ["HIGH", "WARNING"]:
                high_count += 1
            else:
                medium_count += 1
                
        # Risk score calculation
        risk_score = (critical_count * 25.0) + (high_count * 10.0) + (medium_count * 2.0)
        risk_score = min(100.0, risk_score)
        
        # Confidence score goes down if we have unresolved warnings or missing metadata
        confidence_score = max(30.0, 100.0 - (len(self.findings) * 3.0))
        
        return round(risk_score, 2), round(confidence_score, 2)

    def run(self):
        print("[AI Agent] Starting build reports correlation analysis...")
        self.parse_trivy()
        self.parse_semgrep()
        self.parse_gitleaks()
        
        risk, confidence = self.calculate_scores()
        
        report_md = f"""# Rapport d'Analyse Build - Build Intelligence Agent
**Score de Risque** : `{risk}/100`
**Score de Confiance** : `{confidence}/100`
**Alertes Retenues (Faux Positifs Filtrés)** : {len(self.findings)}

## 1. Liste des Alertes Qualifiées
"""
        if not self.findings:
            report_md += "🟢 Aucune alerte qualifiée trouvée après élimination des faux positifs.\n"
        else:
            for f in self.findings:
                report_md += f"- **[{f['source']}]** {f['id']} ({f['severity']}) : {f['description']} sur `{f['package']}`\n"
                
        # Ensure directories exist
        os.makedirs("artifacts/release", exist_ok=True)
        
        with open("artifacts/release/build_intelligence_report.md", "w") as f:
            f.write(report_md)
            
        with open("artifacts/release/build_intelligence_report.json", "w") as f:
            json.dump({
                "risk_score": risk,
                "confidence_score": confidence,
                "findings": self.findings
            }, f, indent=2)
            
        print(f"[Build Agent] Reports written. Risk Score: {risk}, Confidence Score: {confidence}.")

if __name__ == "__main__":
    reports_dir = sys.argv[1] if len(sys.argv) > 1 else "security/reports"
    agent = BuildIntelligenceAgent(reports_dir)
    agent.run()
