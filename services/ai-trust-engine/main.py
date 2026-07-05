import logging
from typing import Dict, Any, List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-trust-engine")

app = FastAPI(
    title="AI Trust Engine Service",
    description="Dynamic Trust Assessment Service for Multi-Master Council agents.",
    version="0.1.0"
)

# Initial trust state for the masters in the council
DEFAULT_TRUST_METRICS = {
    "soc_master": {
        "accuracy": 0.95, "precision": 0.94, "recall": 0.96,
        "false_positive_rate": 0.06, "false_negative_rate": 0.04,
        "latency_ms": 120.0, "hallucination_rate": 0.02, "grounding_score": 0.97
    },
    "threat_master": {
        "accuracy": 0.90, "precision": 0.89, "recall": 0.91,
        "false_positive_rate": 0.11, "false_negative_rate": 0.09,
        "latency_ms": 250.0, "hallucination_rate": 0.05, "grounding_score": 0.91
    },
    "rag_master": {
        "accuracy": 0.92, "precision": 0.93, "recall": 0.91,
        "false_positive_rate": 0.07, "false_negative_rate": 0.09,
        "latency_ms": 350.0, "hallucination_rate": 0.04, "grounding_score": 0.94
    },
    "governance_master": {
        "accuracy": 0.96, "precision": 0.97, "recall": 0.95,
        "false_positive_rate": 0.03, "false_negative_rate": 0.05,
        "latency_ms": 80.0, "hallucination_rate": 0.01, "grounding_score": 0.98
    },
    "threat_hunting_master": {
        "accuracy": 0.88, "precision": 0.87, "recall": 0.89,
        "false_positive_rate": 0.13, "false_negative_rate": 0.11,
        "latency_ms": 300.0, "hallucination_rate": 0.07, "grounding_score": 0.89
    },
    "malware_master": {
        "accuracy": 0.94, "precision": 0.95, "recall": 0.93,
        "false_positive_rate": 0.05, "false_negative_rate": 0.07,
        "latency_ms": 400.0, "hallucination_rate": 0.03, "grounding_score": 0.95
    },
    "compliance_master": {
        "accuracy": 0.93, "precision": 0.92, "recall": 0.94,
        "false_positive_rate": 0.08, "false_negative_rate": 0.06,
        "latency_ms": 150.0, "hallucination_rate": 0.03, "grounding_score": 0.93
    },
    "network_master": {
        "accuracy": 0.91, "precision": 0.90, "recall": 0.92,
        "false_positive_rate": 0.10, "false_negative_rate": 0.08,
        "latency_ms": 110.0, "hallucination_rate": 0.04, "grounding_score": 0.92
    },
    "iam_master": {
        "accuracy": 0.94, "precision": 0.93, "recall": 0.95,
        "false_positive_rate": 0.07, "false_negative_rate": 0.05,
        "latency_ms": 95.0, "hallucination_rate": 0.02, "grounding_score": 0.95
    },
    "forensics_master": {
        "accuracy": 0.89, "precision": 0.88, "recall": 0.90,
        "false_positive_rate": 0.12, "false_negative_rate": 0.10,
        "latency_ms": 500.0, "hallucination_rate": 0.06, "grounding_score": 0.88
    },
    "business_impact_master": {
        "accuracy": 0.85, "precision": 0.84, "recall": 0.86,
        "false_positive_rate": 0.16, "false_negative_rate": 0.14,
        "latency_ms": 180.0, "hallucination_rate": 0.08, "grounding_score": 0.84
    }
}

# Persistent memory state
agent_metrics = DEFAULT_TRUST_METRICS.copy()

class AgentMetricsUpdate(BaseModel):
    agent_id: str
    accuracy: Optional[float] = None
    precision: Optional[float] = None
    recall: Optional[float] = None
    false_positive_rate: Optional[float] = None
    false_negative_rate: Optional[float] = None
    latency_ms: Optional[float] = None
    hallucination_rate: Optional[float] = None
    grounding_score: Optional[float] = None

class TrustScoreResponse(BaseModel):
    agent_id: str
    trust_score: float
    consensus_weight: float
    metrics: Dict[str, float]

def calculate_trust_score(metrics: Dict[str, float]) -> float:
    """
    Computes a composite trust score (0.0 to 1.0) based on accuracy, grounding,
    and penalizing latency and hallucinations.
    """
    acc = metrics.get("accuracy", 0.9)
    prec = metrics.get("precision", 0.9)
    rec = metrics.get("recall", 0.9)
    fpr = metrics.get("false_positive_rate", 0.1)
    fnr = metrics.get("false_negative_rate", 0.1)
    lat = metrics.get("latency_ms", 200.0)
    hal = metrics.get("hallucination_rate", 0.05)
    grd = metrics.get("grounding_score", 0.9)
    
    # Latency penalty: 0 penalty under 100ms, linear penalty up to 1000ms
    lat_penalty = min(0.1, max(0.0, (lat - 100.0) / 900.0 * 0.1))
    
    # Composite score formula
    score = (
        (acc * 0.3) +
        (grd * 0.2) +
        (((prec + rec) / 2.0) * 0.2) +
        ((1.0 - fpr) * 0.1) +
        ((1.0 - fnr) * 0.1) +
        ((1.0 - hal) * 0.1)
    ) - lat_penalty
    
    return round(max(0.0, min(1.0, score)), 4)

@app.get("/api/v1/trust/scores", response_model=Dict[str, TrustScoreResponse])
def get_all_trust_scores():
    """
    Returns the trust scores and consensus weights for all active agents.
    """
    logger.info("Retrieving all agent trust scores...")
    scores = {}
    total_trust = 0.0
    
    # First calculate all raw trust scores
    for agent_id, metrics in agent_metrics.items():
        score = calculate_trust_score(metrics)
        scores[agent_id] = {"score": score, "metrics": metrics}
        total_trust += score
        
    # Standardize weights so they sum to 1.0
    results = {}
    for agent_id, data in scores.items():
        weight = round(data["score"] / total_trust, 4) if total_trust > 0 else 1.0 / len(scores)
        results[agent_id] = TrustScoreResponse(
            agent_id=agent_id,
            trust_score=data["score"],
            consensus_weight=weight,
            metrics=data["metrics"]
        )
        
    return results

@app.post("/api/v1/trust/update", response_model=TrustScoreResponse)
def update_agent_metrics(payload: AgentMetricsUpdate):
    """
    Updates the metrics for a specific agent and recalculates its trust score.
    """
    agent_id = payload.agent_id
    if agent_id not in agent_metrics:
        raise HTTPException(status_code=404, detail=f"Agent '{agent_id}' not found.")
        
    logger.info(f"Updating trust metrics for agent '{agent_id}'")
    metrics = agent_metrics[agent_id]
    
    # Update only the fields that were provided
    update_data = payload.model_dump(exclude_unset=True)
    for key, val in update_data.items():
        if key != "agent_id" and val is not None:
            metrics[key] = val
            
    # Recalculate score
    score = calculate_trust_score(metrics)
    
    # Dynamic weight calculation context
    total_trust = sum(calculate_trust_score(m) for m in agent_metrics.values())
    weight = round(score / total_trust, 4) if total_trust > 0 else 1.0 / len(agent_metrics)
    
    return TrustScoreResponse(
        agent_id=agent_id,
        trust_score=score,
        consensus_weight=weight,
        metrics=metrics
    )

@app.get("/healthz")
def health():
    return {"status": "ok", "service": "ai-trust-engine"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8093)
