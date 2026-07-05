import os
import httpx
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-feedback-engine")

app = FastAPI(
    title="AI Feedback Engine Service",
    description="Feedback loops and Continuous Learning service.",
    version="0.1.0"
)

TRUST_ENGINE_URL = os.getenv("TRUST_ENGINE_URL", "http://localhost:8093")

class FeedbackRequest(BaseModel):
    session_id: str
    verdict_correct: bool
    false_alert: bool
    latency_satisfactory: bool
    analyst_notes: str

@app.post("/api/v1/feedback")
async def process_feedback(payload: FeedbackRequest):
    """
    Ingests analyst feedback on security decisions, triggers dynamic updates
    to the trust metrics of the involved agents, and returns status.
    """
    logger.info(f"Received feedback for session {payload.session_id} (Correct={payload.verdict_correct}, FalseAlert={payload.false_alert})")
    
    # Simulates adjusting the accuracy of the agents
    # In a real environment, we'd query the session to find the active agents,
    # then adjust accuracy and false positive rates.
    target_agents = ["soc_master", "threat_master", "rag_master"]
    
    adjusted_agents = []
    
    # Connect and update the trust engine metrics
    async with httpx.AsyncClient() as client:
        for agent in target_agents:
            # If verdict was correct, increase accuracy slightly
            acc_modifier = 0.98 if payload.verdict_correct else 0.85
            fpr_modifier = 0.04 if not payload.false_alert else 0.15
            
            update_payload = {
                "agent_id": agent,
                "accuracy": acc_modifier,
                "false_positive_rate": fpr_modifier
            }
            
            try:
                resp = await client.post(f"{TRUST_ENGINE_URL}/api/v1/trust/update", json=update_payload)
                if resp.status_code == 200:
                    adjusted_agents.append(agent)
            except Exception as e:
                logger.warning(f"Failed to propagate feedback to trust-engine for '{agent}': {e}")
                
    return {
        "status": "success",
        "processed_feedback": {
            "session_id": payload.session_id,
            "verdict_correct": payload.verdict_correct,
            "false_alert": payload.false_alert,
            "analyst_notes": payload.analyst_notes
        },
        "adjusted_agents": adjusted_agents
    }

@app.get("/healthz")
def health():
    return {"status": "ok", "service": "ai-feedback-engine"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8097)
