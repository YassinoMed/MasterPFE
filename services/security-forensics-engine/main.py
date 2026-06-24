import uvicorn
from fastapi import FastAPI, Request
from prometheus_client import make_asgi_app, Counter
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Security Event Correlation Engine")

# Prometheus Metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

vault_access_counter = Counter("forensic_vault_secret_access_total", "Count of Vault secret access events", ["namespace", "pod"])
container_exec_counter = Counter("forensic_container_exec_total", "Count of container exec events detected by Falco", ["namespace", "pod"])
cilium_anomaly_counter = Counter("forensic_cilium_network_anomalies_total", "Count of Cilium network drops/anomalies", ["source_ns", "dest_ns"])

@app.post("/webhook/falco")
async def falco_webhook(request: Request):
    try:
        payload = await request.json()
        logger.info(f"Received Falco Event: {payload}")
        
        # Example Falco payload parsing
        rule = payload.get("rule")
        if rule == "Terminal shell in container":
            output_fields = payload.get("output_fields", {})
            ns = output_fields.get("k8s.ns.name", "unknown")
            pod = output_fields.get("k8s.pod.name", "unknown")
            container_exec_counter.labels(namespace=ns, pod=pod).inc()
            logger.warning(f"CORRELATION ALERT: Container exec detected in {ns}/{pod}")
            
        return {"status": "processed"}
    except Exception as e:
        logger.error(f"Error processing Falco webhook: {e}")
        return {"status": "error"}

@app.post("/webhook/vault")
async def vault_webhook(request: Request):
    try:
        payload = await request.json()
        # Mocking Vault Audit log processing
        # In reality, Vault audit logs might be read from a file or Kafka topic
        request_path = payload.get("request", {}).get("path", "")
        if "secret/data/" in request_path:
            ns = payload.get("auth", {}).get("metadata", {}).get("service_account_namespace", "unknown")
            pod = payload.get("auth", {}).get("metadata", {}).get("service_account_name", "unknown")
            vault_access_counter.labels(namespace=ns, pod=pod).inc()
            logger.info(f"CORRELATION ALERT: Vault secret accessed by {ns}/{pod}")
            
        return {"status": "processed"}
    except Exception as e:
        logger.error(f"Error processing Vault webhook: {e}")
        return {"status": "error"}

@app.post("/webhook/cilium")
async def cilium_webhook(request: Request):
    try:
        payload = await request.json()
        # Mocking Hubble/Cilium flow processing
        verdict = payload.get("flow", {}).get("verdict", "")
        if verdict == "DROPPED":
            src_ns = payload.get("flow", {}).get("source", {}).get("namespace", "unknown")
            dst_ns = payload.get("flow", {}).get("destination", {}).get("namespace", "unknown")
            cilium_anomaly_counter.labels(source_ns=src_ns, dest_ns=dst_ns).inc()
            logger.warning(f"CORRELATION ALERT: Cilium network drop from {src_ns} to {dst_ns}")
            
        return {"status": "processed"}
    except Exception as e:
        logger.error(f"Error processing Cilium webhook: {e}")
        return {"status": "error"}

@app.get("/healthz")
def healthz():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8080)
