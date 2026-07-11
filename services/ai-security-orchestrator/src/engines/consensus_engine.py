"""
Consensus Engine — Multi-agent voting for security decisions.

Collects independent assessments from all AI agents and computes
a weighted consensus to determine the final security decision.
"""

import structlog
from typing import Dict, List
from fastapi import APIRouter
from pydantic import BaseModel, Field
from prometheus_client import Gauge

logger = structlog.get_logger()

consensus_router = APIRouter()

CONSENSUS_GAUGE = Gauge(
    "ai_consensus_score",
    "Current consensus score among AI agents",
    ["namespace", "service"]
)


class AgentVote(BaseModel):
    """A single agent's security assessment."""
    agent_name: str = Field(..., example="threat_modeler")
    decision: str = Field(..., description="PASS, WARNING, or BLOCK")
    confidence: float = Field(..., ge=0.0, le=100.0)
    risk_score: float = Field(..., ge=0.0, le=100.0)
    reasoning: str = Field("", description="Explanation for the decision")


class ConsensusRequest(BaseModel):
    """Request containing all agent votes."""
    namespace: str = Field("securerag-hub")
    service: str = Field("unknown")
    votes: List[AgentVote] = Field(..., min_length=1)


class ConsensusResponse(BaseModel):
    """Consensus result from multi-agent voting."""
    consensus_score: float = Field(..., ge=0.0, le=100.0)
    final_verdict: str  # PASS, WARNING, BLOCK
    quorum_reached: bool
    total_agents: int
    agents_agree: int
    agents_disagree: int
    weighted_risk_score: float
    agent_breakdown: List[Dict]
    reasoning: str


# Agent weights (importance multiplier)
AGENT_WEIGHTS = {
    "planner": 0.8,
    "threat_modeler": 1.2,
    "code_reviewer": 1.0,
    "docker_auditor": 0.9,
    "k8s_auditor": 1.1,
    "runtime_agent": 1.3,
    "metrics_analyzer": 0.9,
    "risk_engine": 1.5,
}

DECISION_SCORES = {"PASS": 0, "WARNING": 50, "BLOCK": 100}
MIN_QUORUM_RATIO = 0.7  # 70% of agents must agree


@consensus_router.post("/evaluate", response_model=ConsensusResponse)
async def evaluate_consensus(req: ConsensusRequest):
    """Evaluate multi-agent consensus for a security decision."""
    logger.info("consensus_evaluation_started",
                service=req.service, num_agents=len(req.votes))

    if not req.votes:
        return ConsensusResponse(
            consensus_score=0, final_verdict="PASS", quorum_reached=False,
            total_agents=0, agents_agree=0, agents_disagree=0,
            weighted_risk_score=0, agent_breakdown=[], reasoning="No votes received."
        )

    # Calculate weighted scores
    total_weight = 0.0
    weighted_decision_sum = 0.0
    weighted_risk_sum = 0.0
    agent_breakdown = []

    for vote in req.votes:
        weight = AGENT_WEIGHTS.get(vote.agent_name, 1.0)
        confidence_factor = vote.confidence / 100.0
        effective_weight = weight * confidence_factor
        total_weight += effective_weight

        decision_score = DECISION_SCORES.get(vote.decision, 50)
        weighted_decision_sum += decision_score * effective_weight
        weighted_risk_sum += vote.risk_score * effective_weight

        agent_breakdown.append({
            "agent": vote.agent_name,
            "decision": vote.decision,
            "confidence": vote.confidence,
            "risk_score": vote.risk_score,
            "weight": round(effective_weight, 3),
            "reasoning": vote.reasoning,
        })

    # Compute weighted averages
    avg_decision_score = weighted_decision_sum / total_weight if total_weight > 0 else 0
    weighted_risk = weighted_risk_sum / total_weight if total_weight > 0 else 0

    # Determine final verdict
    if avg_decision_score >= 75:
        final_verdict = "BLOCK"
    elif avg_decision_score >= 40:
        final_verdict = "WARNING"
    else:
        final_verdict = "PASS"

    # Check quorum
    majority_decision = final_verdict
    agents_agree = sum(1 for v in req.votes if v.decision == majority_decision)
    agents_disagree = len(req.votes) - agents_agree
    quorum_reached = (agents_agree / len(req.votes)) >= MIN_QUORUM_RATIO

    # Consensus score (100 = full agreement, 0 = complete disagreement)
    consensus_score = round((agents_agree / len(req.votes)) * 100, 2)

    # Build reasoning
    if quorum_reached:
        reasoning = (
            f"Quorum reached: {agents_agree}/{len(req.votes)} agents agree on {final_verdict}. "
            f"Weighted risk score: {weighted_risk:.1f}/100."
        )
    else:
        reasoning = (
            f"WARNING: Quorum NOT reached. Only {agents_agree}/{len(req.votes)} agents agree. "
            f"Manual review recommended. Weighted risk: {weighted_risk:.1f}/100."
        )

    # Update Prometheus
    CONSENSUS_GAUGE.labels(namespace=req.namespace, service=req.service).set(consensus_score)

    logger.info("consensus_evaluation_complete",
                verdict=final_verdict, consensus=consensus_score,
                quorum=quorum_reached, service=req.service)

    return ConsensusResponse(
        consensus_score=consensus_score,
        final_verdict=final_verdict,
        quorum_reached=quorum_reached,
        total_agents=len(req.votes),
        agents_agree=agents_agree,
        agents_disagree=agents_disagree,
        weighted_risk_score=round(weighted_risk, 2),
        agent_breakdown=agent_breakdown,
        reasoning=reasoning,
    )
