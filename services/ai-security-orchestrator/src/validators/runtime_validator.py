"""Runtime Validator — Post-deployment health and security validation."""
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List

logger = structlog.get_logger()
runtime_validator_router = APIRouter()


class RuntimeValidationRequest(BaseModel):
    namespace: str = Field("securerag-hub")
    service: str = Field("unknown")
    pods_ready: int = Field(0)
    pods_total: int = Field(0)
    error_rate: float = Field(0.0)
    p95_latency_ms: float = Field(0.0)
    falco_alerts: int = Field(0)
    argocd_sync_status: str = Field("Synced")
    argocd_health_status: str = Field("Healthy")


class RuntimeValidationResponse(BaseModel):
    healthy: bool
    checks: List[dict]
    issues: List[str]
    recommendation: str


@runtime_validator_router.post("/validate", response_model=RuntimeValidationResponse)
async def validate_runtime(req: RuntimeValidationRequest):
    """Validate runtime health of a deployed service."""
    logger.info("runtime_validation_started", service=req.service)

    checks = []
    issues = []

    # Pod readiness
    pod_ok = req.pods_ready == req.pods_total and req.pods_total > 0
    checks.append({"check": "Pod Readiness", "status": "PASS" if pod_ok else "FAIL",
                    "detail": f"{req.pods_ready}/{req.pods_total} ready"})
    if not pod_ok:
        issues.append(f"Only {req.pods_ready}/{req.pods_total} pods ready")

    # Error rate
    err_ok = req.error_rate < 0.01
    checks.append({"check": "Error Rate", "status": "PASS" if err_ok else "FAIL",
                    "detail": f"{req.error_rate:.2%}"})
    if not err_ok:
        issues.append(f"Error rate {req.error_rate:.2%} exceeds 1% SLO")

    # Latency
    lat_ok = req.p95_latency_ms < 500
    checks.append({"check": "P95 Latency", "status": "PASS" if lat_ok else "WARN",
                    "detail": f"{req.p95_latency_ms:.0f}ms"})
    if not lat_ok:
        issues.append(f"P95 latency {req.p95_latency_ms:.0f}ms exceeds 500ms SLO")

    # Falco
    falco_ok = req.falco_alerts == 0
    checks.append({"check": "Falco Alerts", "status": "PASS" if falco_ok else "FAIL",
                    "detail": f"{req.falco_alerts} alerts"})
    if not falco_ok:
        issues.append(f"{req.falco_alerts} Falco runtime security alerts")

    # ArgoCD
    argo_ok = req.argocd_sync_status == "Synced" and req.argocd_health_status == "Healthy"
    checks.append({"check": "ArgoCD Status", "status": "PASS" if argo_ok else "WARN",
                    "detail": f"Sync:{req.argocd_sync_status} Health:{req.argocd_health_status}"})
    if not argo_ok:
        issues.append(f"ArgoCD: {req.argocd_sync_status}/{req.argocd_health_status}")

    healthy = len(issues) == 0
    recommendation = "Service is healthy and operating within SLOs." if healthy else \
        "Investigate issues. Consider rollback if degradation persists."

    return RuntimeValidationResponse(
        healthy=healthy, checks=checks, issues=issues,
        recommendation=recommendation,
    )
