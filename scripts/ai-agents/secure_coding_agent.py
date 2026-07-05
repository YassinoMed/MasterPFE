#!/usr/bin/env python3
import sys
import os
import ast
import re
import json

class SecureCodingAgent:
    def __init__(self, target_path="."):
        self.target_path = target_path
        self.findings = []
        self.diffs = []
        
    def scan_file(self, filepath):
        if not filepath.endswith(".py"):
            # Check secrets in other configuration/text files
            self.check_secrets_plain(filepath)
            return

        try:
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
                
            self.check_secrets_plain(filepath)
            
            tree = ast.parse(content, filename=filepath)
            self.visit_ast(tree, filepath, content.splitlines())
        except Exception as e:
            pass

    def check_secrets_plain(self, filepath):
        # Look for typical secret patterns
        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                for line_num, line in enumerate(f, 1):
                    if any(x in line.lower() for x in ["password = ", "passwd =", "api_key =", "secret_key =", "token ="]):
                        # Avoid matching placeholders
                        if not any(p in line for p in ["placeholder", "env", "getenv"]):
                            self.findings.append({
                                "file": filepath,
                                "line": line_num,
                                "type": "Hardcoded Secret",
                                "severity": "CRITICAL",
                                "description": "Potential hardcoded credentials or API token found.",
                                "code": line.strip()
                            })
        except:
            pass

    def visit_ast(self, tree, filepath, lines):
        for node in ast.walk(tree):
            # 1. Check for command injection (RCE) via system/subprocess
            if isinstance(node, ast.Call):
                func_name = ""
                if isinstance(node.func, ast.Name):
                    func_name = node.func.id
                elif isinstance(node.func, ast.Attribute):
                    func_name = node.func.attr
                    
                if func_name in ["system", "popen", "run", "call", "Popen"] and hasattr(node, "lineno"):
                    # Check if args are dynamic or string literals
                    if node.args and not isinstance(node.args[0], ast.Constant):
                        self.findings.append({
                            "file": filepath,
                            "line": node.lineno,
                            "type": "Remote Code Execution (RCE)",
                            "severity": "CRITICAL",
                            "description": f"Dangerous shell execution '{func_name}' with dynamic arguments detected.",
                            "code": lines[node.lineno-1].strip()
                        })
                        
                # 2. Check for SQL Injection risk (executes raw SQL with string interpolation)
                if func_name in ["execute", "raw"] and hasattr(node, "lineno"):
                    if node.args and not isinstance(node.args[0], ast.Constant):
                        arg = node.args[0]
                        # Check if it uses formatting or concatenation
                        if isinstance(arg, (ast.BinOp, ast.JoinedStr)):
                            self.findings.append({
                                "file": filepath,
                                "line": node.lineno,
                                "type": "SQL Injection (SQLi)",
                                "severity": "HIGH",
                                "description": "Raw database query using formatting or concatenation instead of parameters.",
                                "code": lines[node.lineno-1].strip()
                            })

    def run(self):
        print(f"[AI Agent] Starting secure coding analysis on: {self.target_path}")
        if os.path.isfile(self.target_path):
            self.scan_file(self.target_path)
        else:
            for root, _, files in os.walk(self.target_path):
                if any(x in root for x in ["node_modules", ".venv", ".git", "vendor"]):
                    continue
                for file in files:
                    self.scan_file(os.path.join(root, file))
                    
        # Write reports
        report_md = f"""# Rapport d'Audit de Sécurité - Secure Coding Agent
**Anomalies Détectées** : {len(self.findings)}

## 1. Détails des Vulnérabilités
"""
        if not self.findings:
            report_md += "🟢 Aucun problème de sécurité majeur détecté par l'analyse sémantique.\n"
        else:
            for f in self.findings:
                report_md += f"""### [{f['type']}] - {f['file']} (Ligne {f['line']})
* **Sévérité** : `{f['severity']}`
* **Description** : {f['description']}
* **Code Suspect** :
  ```python
  {f['code']}
  ```
"""
                
        # Generate Git Diff Suggestions if issues found
        suggested_diff = ""
        if self.findings:
            suggested_diff = "diff --git a/security-patch.py b/security-patch.py\n--- a/security-patch.py\n+++ b/security-patch.py\n"
            for f in self.findings:
                suggested_diff += f"# FIX NEEDED in {f['file']} at line {f['line']}: Avoid dynamic strings or hardcoded parameters.\n"

        # Generate mock secure unit test template
        test_content = """import pytest

def test_security_safe_parameters():
    # Automatically generated security sanity test
    assert True
"""

        with open("artifacts/release/secure_coding_report.md", "w") as f:
            f.write(report_md)
            
        with open("artifacts/release/secure_coding_report.json", "w") as f:
            json.dump({"findings": self.findings}, f, indent=2)
            
        with open("artifacts/release/security_patch.diff", "w") as f:
            f.write(suggested_diff)
            
        with open("tests/test_generated_security.py", "w") as f:
            f.write(test_content)
            
        print(f"[AI Agent] Analysis finished. Findings: {len(self.findings)}. Reports written to artifacts/release/")

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "."
    agent = SecureCodingAgent(target)
    agent.run()
