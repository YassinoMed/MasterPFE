"""
Risk Engine — Multi-source security risk aggregation.

Ingests risk signals from: Semgrep, SonarQube, Trivy, Grype, Falco,
Kyverno, Prometheus, OTel, SBOM, Cosign, Git Diff, Dockerfile, Helm, K8s.

Calculates:
  - Risk Score (0-100)
  - Confidence Score (0-100)
  - Business Impact (LOW/MEDIUM/HIGH/CRITICAL)
  - Exploitability (LOW/MEDIUM/HIGH)
  - Remediation Cost (LOW/MEDIUM/HIGH)
"""

import structlog
from typing import Dict, List, Optional
from fastapi import APIRouter
from pydantic import BaseModel, Field
from prometheus_client import Gauge, Counter

logger = structlog.get_logger()

risk_router = APIRouter()

# Prometheus metrics
RISK_SCORE_GAUGE = Gauge(
    "ai_security_risk_score",
    "Current global risk score",
    ["namespace", "service"]
)
RISK_CALCULATIONS = Counter(
    "ai_risk_calculations_total",
    "Total risk calculations performed",
    ["result"]
)


class RiskInput(BaseModel):
    """Input from all security sources."""
    # Static analysis
    semgrep_findings: int = Field(0, ge=0, description="Number of Semgrep SAST findings")
    semgrep_critical: int = Field(0, ge=0)
    sonar_bugs: int = Field(0, ge=0)
    sonar_vulnerabilities: int = Field(0, ge=0)
    sonar_code_smells: int = Field(0, ge=0)

    # Container/image scanning
    trivy_critical: int = Field(0, ge=0)
    trivy_high: int = Field(0, ge=0)
    trivy_medium: int = Field(0, ge=0)
    grype_critical: int = Field(0, ge=0)
    grype_high: int = Field(0, ge=0)

    # Supply chain
    sbom_present: bool = Field(True)
    cosign_verified: bool = Field(True)
    slsa_provenance_valid: bool = Field(True)
    image_digest_pinned: bool = Field(True)

    # Runtime
    falco_critical_events: int = Field(0, ge=0)
    falco_warning_events: int = Field(0, ge=0)
    kyverno_violations: int = Field(0, ge=0)

    # Infrastructure
    pods_not_ready: int = Field(0, ge=0)
    error_rate_5xx: float = Field(0.0, ge=0.0, le=1.0)
    p95_latency_ms: float = Field(0.0, ge=0.0)
    cpu_utilization: float = Field(0.0, ge=0.0, le=1.0)
    memory_utilization: float = Field(0.0, ge=0.0, le=1.0)

    # Context
    namespace: str = Field("securerag-hub")
    service: str = Field("unknown")
    git_diff_lines_changed: int = Field(0, ge=0)
    is_production: bool = Field(False)


class RiskOutput(BaseModel):
    """Comprehensive risk assessment output."""
    risk_score: float = Field(..., ge=0.0, le=100.0)
    confidence_score: float = Field(..., ge=0.0, le=100.0)
    risk_level: str  # LOW, MEDIUM, HIGH, CRITICAL
    business_impact: str  # LOW, MEDIUM, HIGH, CRITICAL
    exploitability: str  # LOW, MEDIUM, HIGH
    remediation_cost: str  # LOW, MEDIUM, HIGH
    decision: str  # PASS, WARNING, BLOCK
    breakdown: Dict[str, float]
    recommendations: List[str]
    sources_analyzed: int


# Risk weights for each security domain
WEIGHTS = {
    "sast": 0.12,
    "sonar": 0.08,
    "container_scan": 0.15,
    "supply_chain": 0.18,
    "runtime": 0.20,
    "infrastructure": 0.12,
    "kyverno": 0.10,
    "change_risk": 0.05,
}


def _calculate_sast_risk(inp: RiskInput) -> float:
    """Calculate SAST risk from Semgrep findings."""
    score = min(100.0, inp.semgrep_critical * 25 + inp.semgrep_findings * 5)
    return score


def _calculate_sonar_risk(inp: RiskInput) -> float:
    """Calculate SonarQube risk."""
    score = min(100.0, inp.sonar_vulnerabilities * 15 + inp.sonar_bugs * 8 + inp.sonar_code_smells * 1)
    return score


def _calculate_container_risk(inp: RiskInput) -> float:
    """Calculate container scan risk from Trivy + Grype."""
    score = min(100.0,
                (inp.trivy_critical + inp.grype_critical) * 20 +
                (inp.trivy_high + inp.grype_high) * 10 +
                inp.trivy_medium * 3)
    return score


def _calculate_supply_chain_risk(inp: RiskInput) -> float:
    """Calculate supply chain risk."""
    score = 0.0
    if not inp.sbom_present:
        score += 30.0
    if not inp.cosign_verified:
        score += 35.0
    if not inp.slsa_provenance_valid:
        score += 25.0
    if not inp.image_digest_pinned:
        score += 10.0
    return min(100.0, score)


def _calculate_runtime_risk(inp: RiskInput) -> float:
    """Calculate runtime risk from Falco events."""
    score = min(100.0, inp.falco_critical_events * 30 + inp.falco_warning_events * 10)
    return score


def _calculate_infra_risk(inp: RiskInput) -> float:
    """Calculate infrastructure risk."""
    score = 0.0
    score += inp.pods_not_ready * 15
    score += inp.error_rate_5xx * 200  # 0.5 = 100
    score += max(0, (inp.p95_latency_ms - 500) / 10)  # penalty above 500ms
    score += max(0, (inp.cpu_utilization - 0.8) * 200)  # penalty above 80%
    score += max(0, (inp.memory_utilization - 0.85) * 200)  # penalty above 85%
    return min(100.0, score)


def _calculate_kyverno_risk(inp: RiskInput) -> float:
    """Calculate Kyverno policy violation risk."""
    return min(100.0, inp.kyverno_violations * 20)


def _calculate_change_risk(inp: RiskInput) -> float:
    """Calculate risk from code changes."""
    if inp.git_diff_lines_changed > 1000:
        return 60.0
    elif inp.git_diff_lines_changed > 500:
        return 40.0
    elif inp.git_diff_lines_changed > 100:
        return 20.0
    return 5.0


@risk_router.post("/calculate", response_model=RiskOutput)
async def calculate_risk(inp: RiskInput):
    """Calculate comprehensive risk score from all security sources."""
    logger.info("risk_calculation_started", service=inp.service, namespace=inp.namespace)

    breakdown = {
        "sast": _calculate_sast_risk(inp),
        "sonar": _calculate_sonar_risk(inp),
        "container_scan": _calculate_container_risk(inp),
        "supply_chain": _calculate_supply_chain_risk(inp),
        "runtime": _calculate_runtime_risk(inp),
        "infrastructure": _calculate_infra_risk(inp),
        "kyverno": _calculate_kyverno_risk(inp),
        "change_risk": _calculate_change_risk(inp),
    }

    # Weighted aggregate
    risk_score = sum(breakdown[k] * WEIGHTS[k] for k in WEIGHTS)

    # Production multiplier
    if inp.is_production:
        risk_score = min(100.0, risk_score * 1.2)

    risk_score = round(risk_score, 2)

    # Calculate confidence (higher when more sources have data)
    sources_with_data = sum(1 for v in breakdown.values() if v > 0)
    confidence = round(min(100.0, 50 + sources_with_data * 7), 2)

    # Determine levels
    if risk_score >= 75:
        risk_level, business_impact, decision = "CRITICAL", "CRITICAL", "BLOCK"
    elif risk_score >= 50:
        risk_level, business_impact, decision = "HIGH", "HIGH", "WARNING"
    elif risk_score >= 25:
        risk_level, business_impact, decision = "MEDIUM", "MEDIUM", "PASS"
    else:
        risk_level, business_impact, decision = "LOW", "LOW", "PASS"

    # Exploitability
    exploitability = "HIGH" if (inp.trivy_critical + inp.grype_critical) > 0 else \
                     "MEDIUM" if (inp.trivy_high + inp.grype_high) > 0 else "LOW"

    # Remediation cost
    remediation_cost = "HIGH" if risk_score >= 60 else "MEDIUM" if risk_score >= 30 else "LOW"

    # Build recommendations
    recommendations = []
    if breakdown["supply_chain"] > 20:
        recommendations.append("Fix supply chain: ensure SBOM, Cosign signature, and SLSA provenance.")
    if breakdown["container_scan"] > 30:
        recommendations.append("Patch critical/high CVEs in container images immediately.")
    if breakdown["runtime"] > 20:
        recommendations.append("Investigate Falco runtime alerts — possible compromise detected.")
    if breakdown["sast"] > 20:
        recommendations.append("Address SAST findings from Semgrep before merging.")
    if breakdown["kyverno"] > 20:
        recommendations.append("Fix Kyverno policy violations to comply with cluster policies.")
    if not recommendations:
        recommendations.append("All security domains within acceptable thresholds.")

    # Update Prometheus metrics
    RISK_SCORE_GAUGE.labels(namespace=inp.namespace, service=inp.service).set(risk_score)
    RISK_CALCULATIONS.labels(result=decision).inc()

    logger.info("risk_calculation_complete",
                risk_score=risk_score, decision=decision, service=inp.service)

    return RiskOutput(
        risk_score=risk_score,
        confidence_score=confidence,
        risk_level=risk_level,
        business_impact=business_impact,
        exploitability=exploitability,
        remediation_cost=remediation_cost,
        decision=decision,
        breakdown=breakdown,
        recommendations=recommendations,
        sources_analyzed=len(breakdown),
    )
