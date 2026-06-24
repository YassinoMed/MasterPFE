from pydantic import BaseModel, Field
from typing import Dict, Any, List
import uuid
from datetime import datetime

class SecurityEventInput(BaseModel):
    timestamp: str
    source: str = Field(..., description="k8s, vault, ci-cd, cilium, or falco")
    event_type: str
    severity: str
    payload: Dict[str, Any]

class AIModelResponse(BaseModel):
    risk_score: float = Field(..., ge=0.0, le=1.0)
    classification: str
    explanation: str
    confidence: float = Field(..., ge=0.0, le=1.0)

class RoutingEngineResponse(BaseModel):
    event_id: str
    final_risk_score: float = Field(..., ge=0.0, le=1.0)
    risk_level: str
    models_used: List[str]
    explanation: str
    recommended_action: str
    audit_trail_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
