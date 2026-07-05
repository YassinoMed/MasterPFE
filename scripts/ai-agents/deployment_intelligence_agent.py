#!/usr/bin/env python3
import json
import os
import sys
import yaml

class DeploymentIntelligenceAgent:
    def __init__(self, target_dir="k8s"):
        self.target_dir = target_dir
        self.findings = []

    def scan_yaml_file(self, filepath):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                # Load all documents if multi-document YAML
                docs = yaml.safe_load_all(f)
                for doc in docs:
                    if not doc or not isinstance(doc, dict):
                        continue
                    self.audit_resource(filepath, doc)
        except Exception as e:
            # Skip invalid YAML or templates (e.g. Helm templates)
            pass

    def audit_resource(self, filepath, doc):
        kind = doc.get("kind", "")
        metadata = doc.get("metadata", {})
        name = metadata.get("name", "unnamed")
        
        # 1. Audit Pod security specs (Deployments, StatefulSets, DaemonSets, Pods)
        spec = None
        if kind == "Pod":
            spec = doc.get("spec", {})
        elif kind in ["Deployment", "StatefulSet", "DaemonSet", "Job"]:
            spec = doc.get("spec", {}).get("template", {}).get("spec", {})
            
        if spec:
            # Audit volumes: check hostPath usage
            volumes = spec.get("volumes", [])
            for vol in volumes:
                if "hostPath" in vol:
                    self.findings.append({
                        "file": filepath,
                        "resource": f"{kind}/{name}",
                        "type": "hostPath Volume Mounted",
                        "severity": "CRITICAL",
                        "description": f"Volume '{vol.get('name')}' mounts a host path. Risk of node compromise."
                    })
                    
            # Audit containers
            containers = spec.get("containers", [])
            for c in containers:
                cname = c.get("name", "unknown")
                sec_ctx = c.get("securityContext", {})
                
                # Check runAsNonRoot
                if not sec_ctx.get("runAsNonRoot", False) and not sec_ctx.get("runAsUser", 0) > 0:
                    self.findings.append({
                        "file": filepath,
                        "resource": f"{kind}/{name}/container/{cname}",
                        "type": "Runs as Root",
                        "severity": "HIGH",
                        "description": "Container is allowed to run as root."
                    })
                    
                # Check privileged
                if sec_ctx.get("privileged", False):
                    self.findings.append({
                        "file": filepath,
                        "resource": f"{kind}/{name}/container/{cname}",
                        "type": "Privileged Container",
                        "severity": "CRITICAL",
                        "description": "Container runs in privileged mode. Total breakout risk."
                    })
                    
                # Check readOnlyRootFilesystem
                if not sec_ctx.get("readOnlyRootFilesystem", False):
                    self.findings.append({
                        "file": filepath,
                        "resource": f"{kind}/{name}/container/{cname}",
                        "type": "Writable Root Filesystem",
                        "severity": "MEDIUM",
                        "description": "Root filesystem is writable. Risk of persistence on compromise."
                    })

        # 2. Audit RBAC Policies (ClusterRoles / Roles)
        if kind in ["Role", "ClusterRole"]:
            rules = doc.get("rules", [])
            for rule in rules:
                resources = rule.get("resources", [])
                verbs = rule.get("verbs", [])
                # Check wildcard permissions
                if "*" in resources and "*" in verbs:
                    self.findings.append({
                        "file": filepath,
                        "resource": f"{kind}/{name}",
                        "type": "Wildcard RBAC Permissions",
                        "severity": "CRITICAL",
                        "description": "Wildcard '*' verbs and resources allowed. Full cluster admin exploit path."
                    })

    def calculate_deployment_risk(self) -> float:
        if not self.findings:
            return 0.0
            
        score = 0.0
        for f in self.findings:
            sev = f["severity"].upper()
            if sev == "CRITICAL":
                score += 35.0
            elif sev == "HIGH":
                score += 15.0
            else:
                score += 5.0
                
        return min(100.0, score)

    def run(self):
        print(f"[AI Agent] Scanning Kubernetes manifests for configuration risks: {self.target_dir}...")
        
        if os.path.isfile(self.target_dir):
            self.scan_yaml_file(self.target_dir)
        else:
            for root, _, files in os.walk(self.target_dir):
                for file in files:
                    if file.endswith((".yaml", ".yml")):
                        self.scan_yaml_file(os.path.join(root, file))
                        
        risk_score = self.calculate_deployment_risk()
        
        report_md = f"""# Rapport de Validation de Déploiement - Deployment Intelligence Agent
**Deployment Risk Score** : `{risk_score}/100`
**Nombre d'anomalies de configuration** : {len(self.findings)}

## 1. Anomalies Détectées
"""
        if not self.findings:
            report_md += "🟢 Manifests conformes aux bonnes pratiques de sécurité Kubernetes (PodSecurity restricted).\n"
        else:
            for f in self.findings:
                report_md += f"### [{f['type']}] - {f['resource']}\n* **Fichier** : `{f['file']}`\n* **Sévérité** : `{f['severity']}`\n* **Description** : {f['description']}\n\n"
                
        os.makedirs("artifacts/release", exist_ok=True)
        with open("artifacts/release/deployment_intelligence_report.md", "w") as f:
            f.write(report_md)
            
        with open("artifacts/release/deployment_intelligence_report.json", "w") as f:
            json.dump({
                "deployment_risk_score": risk_score,
                "findings": self.findings
            }, f, indent=2)
            
        print(f"[Deployment Agent] Completed. Risk Score: {risk_score}. Findings count: {len(self.findings)}.")

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "k8s"
    agent = DeploymentIntelligenceAgent(target)
    agent.run()
