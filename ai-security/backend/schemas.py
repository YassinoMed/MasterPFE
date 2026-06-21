from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict


class AnalysisResultBase(BaseModel):
    source: str
    classification: str
    severity: str
    confidence: float
    explanation: str
    recommendation: str
    raw_log: str


class AnalysisResultCreate(AnalysisResultBase):
    pass


class AnalysisResultOut(AnalysisResultBase):
    id: int
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)


class SecurityIncidentBase(BaseModel):
    source: str
    severity: str
    confidence: float
    description: str
    recommendation: str
    status: str = "OPEN"


class SecurityIncidentCreate(SecurityIncidentBase):
    pass


class SecurityIncidentUpdate(BaseModel):
    status: str


class SecurityIncidentOut(SecurityIncidentBase):
    id: int
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)


class DashboardStats(BaseModel):
    total_events: int
    malicious_events: int
    suspicious_events: int
    global_risk_score: float
    detection_rate: float
    critical_alerts: List[AnalysisResultOut]
    top_sources: List[dict]
