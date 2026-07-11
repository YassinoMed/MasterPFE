"""Threat Modeling Agent — STRIDE-based threat analysis."""
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Dict

logger = structlog.get_logger()
threat_router = APIRouter()


class ThreatRequest(BaseModel):
    service_name: str = Field(..., example="portal-web")
    architecture_description: str = Field("", example="Web frontend → API → Database")
    exposed_ports: List[int] = Field(default_factory=list)
    has_external_access: bool = Field(False)
    uses_secrets: bool = Field(True)
    uses_database: bool = Field(True)


class ThreatEntry(BaseModel):
    category: str  # Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation
    threat: str
    risk_level: str
    countermeasure: str
    cvss_estimate: float = Field(0.0, ge=0.0, le=10.0)


class ThreatResponse(BaseModel):
    service: str
    threat_count: int
    threats: List[ThreatEntry]
    overall_risk: str
    risk_score: float


@threat_router.post("/analyze", response_model=ThreatResponse)
async def analyze_threats(req: ThreatRequest):
    """Generate STRIDE threat model for a service."""
    logger.info("threat_modeling_started", service=req.service_name)
    threats = []

    # Spoofing
    threats.append(ThreatEntry(
        category="Spoofing",
        threat="Identity spoofing via stolen JWT tokens or API keys",
        risk_level="HIGH" if req.has_external_access else "MEDIUM",
        countermeasure="mTLS between services, JWT validation with short expiry, token rotation",
        cvss_estimate=7.5 if req.has_external_access else 5.0,
    ))

    # Tampering
    threats.append(ThreatEntry(
        category="Tampering",
        threat="Container image tampering or manifest modification in transit",
        risk_level="HIGH",
        countermeasure="Cosign image signatures, SLSA provenance, Kyverno admission validation",
        cvss_estimate=8.0,
    ))

    if req.uses_database:
        threats.append(ThreatEntry(
            category="Tampering",
            threat="SQL injection or data manipulation in database",
            risk_level="CRITICAL",
            countermeasure="Parameterized queries, WAF rules, database audit logging",
            cvss_estimate=9.1,
        ))

    # Repudiation
    threats.append(ThreatEntry(
        category="Repudiation",
        threat="Non-auditable actions in the cluster",
        risk_level="MEDIUM",
        countermeasure="Kubernetes audit logging → Loki, immutable audit trail",
        cvss_estimate=4.0,
    ))

    # Information Disclosure
    if req.uses_secrets:
        threats.append(ThreatEntry(
            category="Information Disclosure",
            threat="Secret leakage via environment variables or logs",
            risk_level="HIGH",
            countermeasure="Vault + ESO injection, log scrubbing, tmpfs secret mounts",
            cvss_estimate=7.0,
        ))

    # DoS
    if req.has_external_access:
        threats.append(ThreatEntry(
            category="Denial of Service",
            threat="DDoS or resource exhaustion on public endpoints",
            risk_level="HIGH",
            countermeasure="Rate limiting, ResourceQuotas, HPA autoscaling, WAF",
            cvss_estimate=7.5,
        ))

    # Elevation of Privilege
    threats.append(ThreatEntry(
        category="Elevation of Privilege",
        threat="Container escape via privilege escalation",
        risk_level="CRITICAL",
        countermeasure="runAsNonRoot, drop ALL caps, seccomp, Falco runtime detection",
        cvss_estimate=9.0,
    ))

    # Calculate overall risk
    max_cvss = max(t.cvss_estimate for t in threats) if threats else 0
    risk_score = round(max_cvss * 10, 2)  # Normalize to 0-100
    overall_risk = "CRITICAL" if max_cvss >= 9 else "HIGH" if max_cvss >= 7 else "MEDIUM"

    return ThreatResponse(
        service=req.service_name,
        threat_count=len(threats),
        threats=threats,
        overall_risk=overall_risk,
        risk_score=risk_score,
    )
