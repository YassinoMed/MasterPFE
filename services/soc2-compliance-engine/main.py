import uvicorn
from fastapi import FastAPI, Request
from prometheus_client import make_asgi_app, Gauge
import asyncio
import logging

from collector import collect_kubernetes_data
from scorer import calculate_score

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="SOC2 Continuous Compliance Engine")

# Prometheus Metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

soc2_score_gauge = Gauge("soc2_compliance_score", "Current SOC2 Compliance Score")
risks_gauge = Gauge("soc2_compliance_risks", "Number of compliance risks", ["severity", "source"])

# In-memory state for simplicity in a stateless-first design.
state = {
    "score": 100,
    "risks": [],
    "drift": []
}

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(background_collector())

async def background_collector():
    while True:
        try:
            logger.info("Collecting Kubernetes compliance data...")
            k8s_data = collect_kubernetes_data()
            
            new_score, risks = calculate_score(k8s_data)
            
            # Record drift if score changes
            if state["score"] != new_score:
                state["drift"].append({
                    "from_score": state["score"],
                    "to_score": new_score,
                    "risks_added": len(risks) - len(state["risks"])
                })
                state["drift"] = state["drift"][-10:]

            state["score"] = new_score
            state["risks"] = risks
            
            # Update metrics
            soc2_score_gauge.set(new_score)
            
            # Reset risks metrics before updating
            # Prometheus client doesn't have a direct clear for labels, so this is a simplified approach
            for risk in risks:
                risks_gauge.labels(severity=risk.get("severity", "unknown"), source=risk.get("source", "unknown")).inc()
                
            logger.info(f"Updated SOC2 Score: {new_score}")
        except Exception as e:
            logger.error(f"Error in background collector: {e}")
        
        await asyncio.sleep(60) # Collect every minute

@app.get("/score")
def get_score():
    return {"soc2_score": state["score"]}

@app.get("/risks")
def get_risks():
    return {"risks": state["risks"]}

@app.get("/drift")
def get_drift():
    return {"drift": state["drift"]}

@app.post("/webhook/falco")
async def falco_webhook(request: Request):
    payload = await request.json()
    logger.info(f"Received Falco event: {payload}")
    return {"status": "received"}

@app.post("/webhook/vault")
async def vault_webhook(request: Request):
    payload = await request.json()
    logger.info(f"Received Vault event: {payload}")
    return {"status": "received"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=False)
