"""AI Planner Agent — Architecture planning and threat analysis."""
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Dict

logger = structlog.get_logger()
planner_router = APIRouter()


class PlanRequest(BaseModel):
    requirements: str = Field(..., example="Deploy portal-web connecting to postgres-auth")
    context: Dict = Field(default_factory=dict)


class PlanResponse(BaseModel):
    plan_id: str
    proposed_architecture: str
    risks: List[str]
    countermeasures: List[str]
    security_requirements: List[str]
    compliance_checks: List[str]


@planner_router.post("/analyze", response_model=PlanResponse)
async def analyze_requirements(req: PlanRequest):
    """Analyze deployment requirements and generate security plan."""
    import uuid
    logger.info("planner_analysis_started", requirements=req.requirements[:100])

    req_lower = req.requirements.lower()
    risks = []
    countermeasures = []
    security_reqs = []
    compliance = []

    if any(w in req_lower for w in ["public", "portal", "ingress", "external"]):
        risks.append("Public exposure: DDoS, OWASP Top 10, API abuse")
        countermeasures.append("WAF + rate limiting + Ingress TLS termination")
        security_reqs.append("Enable HTTPS only, enforce HSTS headers")

    if any(w in req_lower for w in ["postgres", "database", "db", "mysql", "redis"]):
        risks.append("Database exposure: SQL injection, credential leaks")
        countermeasures.append("NetworkPolicy restrict port 5432, Vault secret injection")
        security_reqs.append("Encrypt data at rest and in transit")

    if any(w in req_lower for w in ["secret", "token", "key", "password"]):
        risks.append("Credential management: hardcoded secrets, env exposure")
        countermeasures.append("Vault + ESO injection, never store in ConfigMaps")
        security_reqs.append("Rotate secrets every 90 days")

    if not risks:
        risks.append("Standard deployment risk profile")
        countermeasures.append("Apply standard Kyverno policies and network segmentation")

    compliance = [
        "NIST SP 800-53 AC-6: Least privilege",
        "OWASP ASVS L2: Authentication verification",
        "SLSA Level 3: Build provenance",
        "SOC2 CC6.1: Logical access controls",
    ]

    return PlanResponse(
        plan_id=str(uuid.uuid4()),
        proposed_architecture="Zero-Trust microservices with mTLS, NetworkPolicy isolation, and Vault secrets",
        risks=risks,
        countermeasures=countermeasures,
        security_requirements=security_reqs or ["Standard security baseline"],
        compliance_checks=compliance,
    )
