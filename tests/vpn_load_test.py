#!/usr/bin/env python3
import time
import json
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configurable endpoints
INFERENCE_URL = "http://10.15.10.119:8000/api/predict"
ORCHESTRATOR_URL = "http://10.15.10.119:8082/api/v1/security/council"

CONCURRENCY = 30  # Number of concurrent threads
TOTAL_REQUESTS = 120  # Total requests to send for stress test

def send_request(url, payload):
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=data,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    
    start_time = time.perf_counter()
    status = 0
    error_msg = ""
    try:
        # 12 seconds timeout to handle remote inference queueing
        with urllib.request.urlopen(req, timeout=12.0) as response:
            status = response.status
            response.read()
    except urllib.error.HTTPError as e:
        status = e.code
        error_msg = str(e)
    except Exception as e:
        status = 500
        error_msg = str(e)
        
    end_time = time.perf_counter()
    latency = (end_time - start_time) * 1000.0  # in ms
    return status, latency, error_msg

def run_stress_test(url, name, payload):
    print(f"\n[Load Test] Starting heavy stress test on: {name} ({url})...")
    print(f"            Concurrency: {CONCURRENCY} threads | Total Requests: {TOTAL_REQUESTS}")
    
    latencies = []
    success_count = 0
    failure_count = 0
    errors = {}
    
    start_test_time = time.perf_counter()
    
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as executor:
        futures = {executor.submit(send_request, url, payload): i for i in range(TOTAL_REQUESTS)}
        for fut in as_completed(futures):
            status, latency, err = fut.result()
            if status in [200, 201]:
                success_count += 1
                latencies.append(latency)
            else:
                failure_count += 1
                errors[status] = errors.get(status, 0) + 1
                
    end_test_time = time.perf_counter()
    total_test_duration = end_test_time - start_test_time
    
    # Calculate statistics
    latencies.sort()
    avg_latency = sum(latencies) / len(latencies) if latencies else -1.0
    p95_latency = latencies[int(len(latencies) * 0.95)] if latencies else -1.0
    p99_latency = latencies[int(len(latencies) * 0.99)] if latencies else -1.0
    max_latency = latencies[-1] if latencies else -1.0
    min_latency = latencies[0] if latencies else -1.0
    
    throughput = TOTAL_REQUESTS / total_test_duration
    success_rate = (success_count / TOTAL_REQUESTS) * 100.0
    
    report = f"""# Rapport de Stress Test Performance - {name}
*   **Hôte cible** : `{url}`
*   **Nombre de requêtes** : `{TOTAL_REQUESTS}`
*   **Parallélisme (Concurrency)** : `{CONCURRENCY}` threads
*   **Durée totale du test** : `{total_test_duration:.2f} secondes`
*   **Débit moyen (Throughput)** : `{throughput:.2f} req/s`

## 1. Métriques de Latence et Succès
| Indicateur | Valeur |
| :--- | :--- |
| **Taux de succès** | `{success_rate:.2f}%` ({success_count}/{TOTAL_REQUESTS}) |
| **Taux d'échec** | `{100.0 - success_rate:.2f}%` ({failure_count}/{TOTAL_REQUESTS}) |
| **Latence Minimale** | `{min_latency:.2f} ms` |
| **Latence Moyenne** | `{avg_latency:.2f} ms` |
| **Latence p95** | `{p95_latency:.2f} ms` |
| **Latence p99** | `{p99_latency:.2f} ms` |
| **Latence Maximale** | `{max_latency:.2f} ms` |

## 2. Répartition des Erreurs
"""
    if not errors:
        report += "🟢 Aucune erreur réseau ou applicative détectée.\n"
    else:
        report += "| Code HTTP | Nombre d'occurrences |\n| :--- | :--- |\n"
        for code, count in errors.items():
            report += f"| `{code}` | `{count}` |\n"
            
    print(f"[Load Test] Finished {name}. Success: {success_rate:.2f}%. Avg Latency: {avg_latency:.2f} ms.")
    return report, success_rate

def main():
    payload_inference = {
        "model": "smollm2_1_7b",
        "prompt": "Evaluate security log: process exec /bin/sh -i (parent bash)"
    }
    payload_orchestrator = {
        "query": "process exec /bin/sh -i (parent bash) - container interactive shell warning"
    }
    
    # Run test on Inference Server (Port 8000)
    inf_report, inf_ok = run_stress_test(INFERENCE_URL, "Inference Server GPU", payload_inference)
    
    # Run test on Orchestrator Gateway (Port 8082)
    orch_report, orch_ok = run_stress_test(ORCHESTRATOR_URL, "AI Orchestrator Multi-Master", payload_orchestrator)
    
    # Write report files
    import os
    os.makedirs("artifacts/release", exist_ok=True)
    
    with open("artifacts/release/vpn_inference_stress_report.md", "w") as f:
        f.write(inf_report)
        
    with open("artifacts/release/vpn_orchestrator_stress_report.md", "w") as f:
        f.write(orch_report)
        
    print("\n[AI Load Test] Stress tests completed. Reports written to artifacts/release/.")

if __name__ == "__main__":
    main()
