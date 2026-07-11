"""Runtime Security Agent — Real-time security event analysis."""
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Dict
from prometheus_client import Counter

logger = structlog.get_logger()
runtime_router = APIRouter()

RUNTIME_EVENTS = Counter("ai_runtime_events_total", "Runtime events analyzed", ["severity"])


class RuntimeEvent(BaseModel):
    source: str = Field(..., example="falco")
    event_type: str = Field(..., example="shell_in_container")
    severity: str = Field("WARNING")
    namespace: str = Field("securerag-hub")
    pod: str = Field("")
    container: str = Field("")
    description: str = Field("")
    timestamp: str = Field("")


class RuntimeAnalysisRequest(BaseModel):
    events: List[RuntimeEvent] = Field(default_factory=list)
    prometheus_error_rate: float = Field(0.0)
    prometheus_p95_latency: float = Field(0.0)


class RuntimeAction(BaseModel):
    action: str
    target: str
    reason: str
    automated: bool


class RuntimeAnalysisResponse(BaseModel):
    total_events: int
    critical_events: int
    risk_score: float
    decision: str
    requires_rollback: bool
    requires_incident: bool
    actions: List[RuntimeAction]
    summary: str


@runtime_router.post("/analyze", response_model=RuntimeAnalysisResponse)
async def analyze_runtime(req: RuntimeAnalysisRequest):
    """Analyze runtime security events and recommend actions."""
    logger.info("runtime_analysis_started", num_events=len(req.events))

    actions = []
    critical_count = 0
    risk_score = 0.0
    requires_rollback = False
    requires_incident = False

    for event in req.events:
        RUNTIME_EVENTS.labels(severity=event.severity).inc()

        if event.severity in ("CRITICAL", "EMERGENCY"):
            critical_count += 1
            risk_score += 30

            if "shell" in event.event_type.lower():
                actions.append(RuntimeAction(
                    action="KILL_POD", target=f"{event.namespace}/{event.pod}",
                    reason="Interactive shell detected — possible compromise",
                    automated=True,
                ))
                requires_incident = True

            elif "privilege" in event.event_type.lower():
                actions.append(RuntimeAction(
                    action="ISOLATE_NAMESPACE", target=event.namespace,
                    reason="Privilege escalation attempt detected",
                    automated=True,
                ))
                requires_rollback = True
                requires_incident = True

            elif "cryptomining" in event.event_type.lower():
                actions.append(RuntimeAction(
                    action="KILL_POD", target=f"{event.namespace}/{event.pod}",
                    reason="Cryptomining activity detected",
                    automated=True,
                ))
                actions.append(RuntimeAction(
                    action="BLOCK_EGRESS", target=event.namespace,
                    reason="Block outbound traffic from compromised namespace",
                    automated=True,
                ))
                requires_incident = True

        elif event.severity == "WARNING":
            risk_score += 10

    # Check Prometheus metrics
    if req.prometheus_error_rate > 0.10:
        risk_score += 25
        actions.append(RuntimeAction(
            action="ROLLBACK", target="securerag-hub",
            reason=f"Error rate {req.prometheus_error_rate:.1%} exceeds 10% threshold",
            automated=True,
        ))
        requires_rollback = True

    if req.prometheus_p95_latency > 2.0:
        risk_score += 15
        actions.append(RuntimeAction(
            action="ALERT", target="securerag-hub",
            reason=f"P95 latency {req.prometheus_p95_latency:.2f}s exceeds 2s SLO",
            automated=False,
        ))

    risk_score = min(100.0, risk_score)
    decision = "BLOCK" if risk_score >= 75 else "WARNING" if risk_score >= 40 else "PASS"

    summary = (
        f"Runtime analysis: {len(req.events)} events, {critical_count} critical. "
        f"Risk: {risk_score}/100. Decision: {decision}. "
        f"Rollback: {'YES' if requires_rollback else 'NO'}."
    )

    return RuntimeAnalysisResponse(
        total_events=len(req.events), critical_events=critical_count,
        risk_score=risk_score, decision=decision,
        requires_rollback=requires_rollback, requires_incident=requires_incident,
        actions=actions, summary=summary,
    )
