#!/usr/bin/env python3
import json
import os
import sys
import httpx

class AITestingAgent:
    def __init__(self, base_url="http://localhost:8080"):
        self.base_url = base_url
        self.payloads = {
            "sqli": [
                "' OR 1=1 --",
                "admin' --",
                "' UNION SELECT username, password FROM users --"
            ],
            "xss": [
                "<script>alert('xss')</script>",
                "<img src=x onerror=alert(1)>",
                "javascript:alert(1)"
            ],
            "ssrf": [
                "http://169.254.169.254/latest/meta-data/",
                "http://localhost:8093/api/v1/trust/scores",
                "http://127.0.0.1:8500"
            ],
            "rce": [
                "; cat /etc/passwd",
                "| id",
                "$(whoami)"
            ],
            "jwt": [
                "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJhZG1pbiJ9.",
                "invalid_signature_token"
            ]
        }
        self.test_results = []

    def fuzz_endpoint(self, path="/api/v1/analyze"):
        url = f"{self.base_url}{path}"
        print(f"[AI Testing Agent] Fuzzing endpoint: {url}...")
        
        for attack_type, payload_list in self.payloads.items():
            for payload in payload_list:
                # Prepare fuzz payload
                test_payload = {
                    "source": "testing-agent",
                    "raw_log": f"Fuzz test: {attack_type} payload: {payload}"
                }
                status_code = 0
                response_text = ""
                try:
                    # In a real DAST run, we would send this to the API Gateway or FastAPI endpoints
                    with httpx.Client(timeout=3.0) as client:
                        resp = client.post(url, json=test_payload)
                        status_code = resp.status_code
                        response_text = resp.text[:100]
                except Exception as e:
                    # If endpoint is offline, we record a connection issue but mark it as handled (fail-safe)
                    status_code = 500
                    response_text = f"Connection failed: {e}"
                    
                self.test_results.append({
                    "attack_type": attack_type,
                    "payload": payload,
                    "endpoint": path,
                    "response_status": status_code,
                    "verdict": "SAFE" if status_code in [400, 401, 403, 404, 422] or "NORMAL" in response_text else "VULNERABLE"
                })

    def run(self):
        # Scan endpoints (FastAPI Gateway)
        self.fuzz_endpoint("/health")
        self.fuzz_endpoint("/analyze")
        
        report_md = f"""# Rapport de Tests Sécurité Dynamiques - AI Testing Agent
**Type de test** : Fuzzing & DAST intelligent
**Total des cas de tests exécutés** : {len(self.test_results)}

## 1. Résultats détaillés du Fuzzing
"""
        vulnerable_count = 0
        for res in self.test_results:
            verdict_color = "🟢 SAFE" if res["verdict"] == "SAFE" else "🔴 VULNERABLE"
            if res["verdict"] != "SAFE":
                vulnerable_count += 1
            report_md += f"""* **Type d'attaque** : `{res['attack_type']}`
  * Payload : `{res['payload']}`
  * Endpoint ciblé : `{res['endpoint']}`
  * Statut réponse : `{res['response_status']}`
  * Verdict : **{verdict_color}**
"""
            
        os.makedirs("artifacts/release", exist_ok=True)
        with open("artifacts/release/ai_testing_report.md", "w") as f:
            f.write(report_md)
            
        with open("artifacts/release/ai_testing_report.json", "w") as f:
            json.dump({
                "vulnerabilities_found": vulnerable_count,
                "results": self.test_results
            }, f, indent=2)
            
        print(f"[AI Testing Agent] Fuzzing complete. Vulnerabilities found: {vulnerable_count}. Written to artifacts/release/ai_testing_report.md.")

if __name__ == "__main__":
    base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080"
    agent = AITestingAgent(base_url)
    agent.run()
