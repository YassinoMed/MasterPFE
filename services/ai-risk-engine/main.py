import logging
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-risk-engine")

app = FastAPI(
    title="AI Risk Engine Service",
    description="Global Risk Calculation Service for AI-Native DevSecOps.",
    version="0.1.0"
)

class RiskCalculationRequest(BaseModel):
    commit_risk: float = Field(0.0, ge=0.0, le=100.0)
    source_code_risk: float = Field(0.0, ge=0.0, le=100.0)
    dependency_risk: float = Field(0.0, ge=0.0, le=100.0)
    container_risk: float = Field(0.0, ge=0.0, le=100.0)
    image_risk: float = Field(0.0, ge=0.0, le=100.0)
    kubernetes_risk: float = Field(0.0, ge=0.0, le=100.0)
    runtime_risk: float = Field(0.0, ge=0.0, le=100.0)
    compliance_risk: float = Field(0.0, ge=0.0, le=100.0)
    network_risk: float = Field(0.0, ge=0.0, le=100.0)
    cloud_risk: float = Field(0.0, ge=0.0, le=100.0)

class RiskCalculationResponse(BaseModel):
    global_risk_score: float
    risk_level: str
    breakdown: Dict[str, float]
    recommendation: str

@app.post("/api/v1/risk/calculate", response_model=RiskCalculationResponse)
def calculate_risk(payload: RiskCalculationRequest):
    """
    Calculates global risk score using dynamic weight parameters.
    """
    logger.info("Calculating global risk score...")
    
    # Weights defining relative importance of each security domain
    weights = {
        "commit_risk": 0.05,
        "source_code_risk": 0.15,
        "dependency_risk": 0.10,
        "container_risk": 0.10,
        "image_risk": 0.10,
        "kubernetes_risk": 0.10,
        "runtime_risk": 0.20,
        "compliance_risk": 0.05,
        "network_risk": 0.10,
        "cloud_risk": 0.05
    }
    
    breakdown = payload.model_dump()
    
    weighted_sum = 0.0
    for key, weight in weights.items():
        weighted_sum += breakdown[key] * weight
        
    global_score = round(weighted_sum, 2)
    
    # Determine risk level
    if global_score >= 75.0:
        risk_level = "CRITICAL"
        recommendation = "BLOCKED: Global risk exceeds threshold. Roll back deployment and patch immediately."
    elif global_score >= 50.0:
        risk_level = "HIGH"
        recommendation = "WARNING: Significant security concerns. Manual inspection of anomalies required."
    elif global_score >= 25.0:
        risk_level = "MEDIUM"
        recommendation = "MONITOR: Moderate concerns. Verify vulnerability lifecycle states."
    else:
        risk_level = "LOW"
        recommendation = "ACCEPT: Normal security state. Proceed with standard lifecycle operations."
        
    return RiskCalculationResponse(
        global_risk_score=global_score,
        risk_level=risk_level,
        breakdown=breakdown,
        recommendation=recommendation
    )

@app.get("/healthz")
def health():
    return {"status": "ok", "service": "ai-risk-engine"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8092)
