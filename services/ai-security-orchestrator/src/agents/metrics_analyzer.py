"""Metrics Analyzer Agent — Prometheus/OTel metrics analysis."""
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import Dict, List

logger = structlog.get_logger()
metrics_router = APIRouter()


class MetricsRequest(BaseModel):
    namespace: str = Field("securerag-hub")
    service: str = Field("unknown")
    error_rate_5xx: float = Field(0.0, ge=0.0, le=1.0)
    error_rate_4xx: float = Field(0.0, ge=0.0, le=1.0)
    p50_latency_ms: float = Field(0.0, ge=0.0)
    p95_latency_ms: float = Field(0.0, ge=0.0)
    p99_latency_ms: float = Field(0.0, ge=0.0)
    requests_per_second: float = Field(0.0, ge=0.0)
    cpu_utilization: float = Field(0.0, ge=0.0, le=1.0)
    memory_utilization: float = Field(0.0, ge=0.0, le=1.0)
    pod_restart_count: int = Field(0, ge=0)
    pods_ready: int = Field(0, ge=0)
    pods_total: int = Field(0, ge=0)


class MetricsResponse(BaseModel):
    service: str
    health_status: str
    slo_compliance: Dict[str, bool]
    anomalies: List[str]
    risk_score: float
    decision: str
    recommendations: List[str]


# SLO definitions
SLOS = {
    "error_rate_5xx": 0.01,       # < 1%
    "p95_latency_ms": 500.0,      # < 500ms
    "p99_latency_ms": 1000.0,     # < 1s
    "cpu_utilization": 0.80,       # < 80%
    "memory_utilization": 0.85,    # < 85%
}


@metrics_router.post("/analyze", response_model=MetricsResponse)
async def analyze_metrics(req: MetricsRequest):
    """Analyze service metrics against SLO definitions."""
    logger.info("metrics_analysis_started", service=req.service)

    anomalies = []
    recommendations = []
    risk_score = 0.0

    slo_compliance = {}

    # Error rate SLO
    slo_compliance["error_rate_5xx"] = req.error_rate_5xx < SLOS["error_rate_5xx"]
    if not slo_compliance["error_rate_5xx"]:
        anomalies.append(f"5xx error rate {req.error_rate_5xx:.2%} exceeds SLO ({SLOS['error_rate_5xx']:.0%})")
        risk_score += 30
        recommendations.append("Investigate 5xx errors — check application logs and dependencies")

    # Latency SLOs
    slo_compliance["p95_latency"] = req.p95_latency_ms < SLOS["p95_latency_ms"]
    if not slo_compliance["p95_latency"]:
        anomalies.append(f"P95 latency {req.p95_latency_ms:.0f}ms exceeds SLO ({SLOS['p95_latency_ms']:.0f}ms)")
        risk_score += 15
        recommendations.append("Profile application for performance bottlenecks")

    slo_compliance["p99_latency"] = req.p99_latency_ms < SLOS["p99_latency_ms"]
    if not slo_compliance["p99_latency"]:
        anomalies.append(f"P99 latency {req.p99_latency_ms:.0f}ms exceeds SLO ({SLOS['p99_latency_ms']:.0f}ms)")
        risk_score += 10

    # Resource utilization
    slo_compliance["cpu"] = req.cpu_utilization < SLOS["cpu_utilization"]
    if not slo_compliance["cpu"]:
        anomalies.append(f"CPU utilization {req.cpu_utilization:.0%} exceeds threshold")
        risk_score += 15
        recommendations.append("Scale horizontally with HPA or increase CPU limits")

    slo_compliance["memory"] = req.memory_utilization < SLOS["memory_utilization"]
    if not slo_compliance["memory"]:
        anomalies.append(f"Memory utilization {req.memory_utilization:.0%} exceeds threshold")
        risk_score += 15
        recommendations.append("Check for memory leaks, increase limits or optimize")

    # Pod health
    if req.pod_restart_count > 3:
        anomalies.append(f"High pod restart count: {req.pod_restart_count}")
        risk_score += 20
        recommendations.append("Investigate OOMKilled or CrashLoopBackOff causes")

    if req.pods_total > 0 and req.pods_ready < req.pods_total:
        anomalies.append(f"Not all pods ready: {req.pods_ready}/{req.pods_total}")
        risk_score += 10

    risk_score = min(100.0, risk_score)

    # Determine health
    slo_pass_count = sum(1 for v in slo_compliance.values() if v)
    slo_total = len(slo_compliance)
    if slo_pass_count == slo_total:
        health_status = "HEALTHY"
    elif slo_pass_count >= slo_total * 0.6:
        health_status = "DEGRADED"
    else:
        health_status = "UNHEALTHY"

    decision = "BLOCK" if risk_score >= 60 else "WARNING" if risk_score >= 25 else "PASS"

    if not recommendations:
        recommendations.append("All metrics within SLO thresholds. Service is healthy.")

    return MetricsResponse(
        service=req.service, health_status=health_status,
        slo_compliance=slo_compliance, anomalies=anomalies,
        risk_score=risk_score, decision=decision,
        recommendations=recommendations,
    )
