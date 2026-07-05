#!/usr/bin/env python3
import json
import os
import sys
import httpx
import time

class AIOperationsAgent:
    def __init__(self, backend_url="http://10.15.10.119:8082"):
        self.backend_url = backend_url

    def analyze_log_event(self, source, log_message):
        print(f"[AI Operations Agent] Correlating threat log from '{source}'...")
        
        # Detect remote orchestrator gateway port to apply appropriate routing & payload mapping
        if "8082" in self.backend_url:
            url = f"{self.backend_url}/api/v1/security/council"
            payload = {"query": f"Source: {source} | Log: {log_message}"}
        else:
            url = f"{self.backend_url}/analyze"
            payload = {"source": source, "raw_log": log_message}
            
        try:
            with httpx.Client(timeout=10.0) as client:
                resp = client.post(url, json=payload)
                if resp.status_code == 200:
                    data = resp.json()
                    if "8082" in self.backend_url:
                        consensus = data.get("consensus", {})
                        verdict = consensus.get("final_verdict", "ACCEPT")
                        confidence = consensus.get("consensus_score", 0.0)
                        justification = consensus.get("justification", "No justification provided.")
                        
                        risk = data.get("risk_assessment", {})
                        severity = risk.get("severity", "LOW")
                        
                        journal = data.get("decision_journal", {})
                        recommendations = journal.get("recommended_next_steps", [])
                        rec_str = ", ".join(recommendations) if recommendations else "No specific action required."
                        
                        print(f"[AI Operations Agent] Verdict: {verdict}, Consensus Score: {confidence}% (Severity: {severity})")
                        print(f"Justification: {justification}")
                        print(f"Recommendations: {rec_str}")
                        
                        return {
                            "classification": verdict,
                            "confidence": confidence,
                            "explanation": justification,
                            "recommendation": rec_str
                        }
                    else:
                        print(f"[AI Operations Agent] Verdict: {data.get('classification')}, Confidence: {data.get('confidence')}%")
                        print(f"Explanation: {data.get('explanation')}")
                        print(f"Remediation: {data.get('recommendation')}")
                        return data
                else:
                    print(f"[AI Operations Agent] Error: Backend returned status code {resp.status_code}")
        except Exception as e:
            print(f"[AI Operations Agent] Error communicating with backend: {e}")
            # Fallback mock decision if backend is offline to ensure zero disruption (fail-safe)
            return {
                "classification": "SUSPICIOUS",
                "confidence": 85.0,
                "severity": "HIGH",
                "explanation": f"Log operations agent fallback due to error: {e}",
                "recommendation": "Review logs manually."
            }

    def run(self):
        # Scan a set of sample logs to demonstrate active threat hunting
        sample_logs = [
            ("Tetragon", "process exec /bin/sh -i (parent bash) - container execution"),
            ("Falco", "Rule: Read sensitive file untrusted - /etc/shadow read by www-data"),
            ("Istio", "IngressGateway: SQL Injection payload detected: 'union select username, password'")
        ]
        
        results = []
        for src, log in sample_logs:
            res = self.analyze_log_event(src, log)
            results.append({
                "source": src,
                "log": log,
                "analysis": res
            })
            time.sleep(0.5)
            
        os.makedirs("artifacts/release", exist_ok=True)
        with open("artifacts/release/ai_operations_report.json", "w") as f:
            json.dump(results, f, indent=2)

if __name__ == "__main__":
    backend = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080"
    agent = AIOperationsAgent(backend)
    agent.run()
