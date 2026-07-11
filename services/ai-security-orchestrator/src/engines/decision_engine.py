"""
Decision Engine — Final PASS/WARNING/BLOCK decision.

Combines Risk Engine output + Consensus Engine output to make the
final deployment/runtime decision.
"""

import structlog
from datetime import datetime, timezone
from typing import Dict, List, Optional
from fastapi import APIRouter
from pydantic import BaseModel, Field
from prometheus_client import Counter

logger = structlog.get_logger()

decision_router = APIRouter()

DECISION_COUNTER = Counter(
    "ai_decisions_total",
    "Total AI decisions made",
    ["decision", "namespace"]
)


class DecisionInput(BaseModel):
    """Combined input from risk and consensus engines."""
    namespace: str = Field("securerag-hub")
    service: str = Field("unknown")
    pipeline_id: str = Field("unknown")

    # From Risk Engine
    risk_score: float = Field(0.0, ge=0.0, le=100.0)
    risk_level: str = Field("LOW")
    business_impact: str = Field("LOW")
    exploitability: str = Field("LOW")

    # From Consensus Engine
    consensus_score: float = Field(100.0, ge=0.0, le=100.0)
    consensus_verdict: str = Field("PASS")
    quorum_reached: bool = Field(True)

    # Supply chain
    sbom_present: bool = Field(True)
    cosign_verified: bool = Field(True)
    slsa_valid: bool = Field(True)

    # Override
    manual_override: Optional[str] = Field(None, description="FORCE_PASS or FORCE_BLOCK")


class DecisionOutput(BaseModel):
    """Final decision output."""
    decision: str  # PASS, WARNING, BLOCK
    decision_id: str
    timestamp: str
    risk_score: float
    consensus_score: float
    reasoning: List[str]
    actions: List[str]
    requires_human_review: bool
    rollback_recommended: bool
    metadata: Dict


@decision_router.post("/evaluate", response_model=DecisionOutput)
async def evaluate_decision(inp: DecisionInput):
    """Make the final security decision."""
    logger.info("decision_evaluation_started",
                service=inp.service, risk=inp.risk_score, consensus=inp.consensus_score)

    reasoning = []
    actions = []
    requires_human_review = False
    rollback_recommended = False

    # Check manual override
    if inp.manual_override == "FORCE_PASS":
        decision = "PASS"
        reasoning.append("MANUAL OVERRIDE: Decision forced to PASS by authorized operator.")
    elif inp.manual_override == "FORCE_BLOCK":
        decision = "BLOCK"
        reasoning.append("MANUAL OVERRIDE: Decision forced to BLOCK by authorized operator.")
    else:
        # Automatic decision logic
        decision = "PASS"

        # Rule 1: Supply chain violations are automatic BLOCK
        if not inp.cosign_verified:
            decision = "BLOCK"
            reasoning.append("BLOCK: Image signature verification failed (Cosign).")
            actions.append("Reject deployment. Image must be re-signed.")

        if not inp.sbom_present:
            decision = "BLOCK"
            reasoning.append("BLOCK: No SBOM attestation found.")
            actions.append("Generate and attach SBOM before deployment.")

        if not inp.slsa_valid:
            decision = "BLOCK"
            reasoning.append("BLOCK: SLSA provenance validation failed.")
            actions.append("Rebuild from trusted CI/CD pipeline with provenance.")

        # Rule 2: Critical risk score
        if inp.risk_score >= 75:
            decision = "BLOCK"
            reasoning.append(f"BLOCK: Risk score {inp.risk_score}/100 exceeds CRITICAL threshold (75).")
            actions.append("Address critical security findings before re-deploying.")
            rollback_recommended = True

        # Rule 3: High risk score
        elif inp.risk_score >= 50:
            if decision != "BLOCK":
                decision = "WARNING"
            reasoning.append(f"WARNING: Risk score {inp.risk_score}/100 exceeds HIGH threshold (50).")
            actions.append("Review security findings. Deployment allowed with monitoring.")
            requires_human_review = True

        # Rule 4: Consensus disagreement
        if not inp.quorum_reached and decision != "BLOCK":
            decision = "WARNING"
            reasoning.append("WARNING: AI agent quorum not reached — agents disagree on security posture.")
            requires_human_review = True
            actions.append("Manual security review required before production promotion.")

        # Rule 5: Low consensus score
        if inp.consensus_score < 50 and decision != "BLOCK":
            decision = "WARNING"
            reasoning.append(f"WARNING: Low consensus score ({inp.consensus_score}%) — significant disagreement.")
            requires_human_review = True

        # Rule 6: No issues found
        if not reasoning:
            reasoning.append(f"PASS: All security checks passed. Risk: {inp.risk_score}/100, Consensus: {inp.consensus_score}%.")
            actions.append("Deployment approved. Continue with progressive delivery.")

    # Build decision ID
    decision_id = f"dec-{inp.service}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"

    # Update Prometheus
    DECISION_COUNTER.labels(decision=decision, namespace=inp.namespace).inc()

    logger.info("decision_evaluation_complete",
                decision=decision, decision_id=decision_id,
                service=inp.service, risk=inp.risk_score)

    return DecisionOutput(
        decision=decision,
        decision_id=decision_id,
        timestamp=datetime.now(timezone.utc).isoformat(),
        risk_score=inp.risk_score,
        consensus_score=inp.consensus_score,
        reasoning=reasoning,
        actions=actions,
        requires_human_review=requires_human_review,
        rollback_recommended=rollback_recommended,
        metadata={
            "namespace": inp.namespace,
            "service": inp.service,
            "pipeline_id": inp.pipeline_id,
            "risk_level": inp.risk_level,
            "business_impact": inp.business_impact,
            "exploitability": inp.exploitability,
        }
    )
