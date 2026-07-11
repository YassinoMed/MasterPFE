"""
AI Security Orchestrator — Main Application
Central orchestration layer for the AI-Native DevSecOps platform.

Exposes API endpoints for:
- Risk calculation (multi-source aggregation)
- AI consensus engine (multi-agent voting)
- Decision engine (PASS/WARNING/BLOCK)
- Runtime analysis loop
- Knowledge graph queries
- Auto-remediation triggers
"""

import os
import logging
import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

from src.config import settings
from src.engines.risk_engine import risk_router
from src.engines.consensus_engine import consensus_router
from src.engines.decision_engine import decision_router
from src.agents.planner import planner_router
from src.agents.threat_modeler import threat_router
from src.agents.code_reviewer import code_review_router
from src.agents.docker_auditor import docker_audit_router
from src.agents.k8s_auditor import k8s_audit_router
from src.agents.runtime_agent import runtime_router
from src.agents.metrics_analyzer import metrics_router
from src.agents.report_generator import report_router
from src.validators.deployment_validator import deployment_validator_router
from src.validators.runtime_validator import runtime_validator_router
from src.bus.event_bus import EventBus

# Configure structured logging
structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.dev.set_exc_info,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
)

logger = structlog.get_logger()

from src.runtime.loop import RuntimeLoop

# Global event bus instance
event_bus = EventBus()
runtime_loop = RuntimeLoop(event_bus)


@asynccontextmanager
async def lifespan(application: FastAPI):
    """Application lifecycle: startup and shutdown events."""
    logger.info("ai_security_orchestrator_starting",
                version=settings.VERSION,
                environment=settings.ENVIRONMENT)
    await event_bus.start()
    await runtime_loop.start()
    yield
    await runtime_loop.stop()
    await event_bus.stop()
    logger.info("ai_security_orchestrator_stopped")


app = FastAPI(
    title="AI Security Orchestrator",
    description=(
        "Central AI-Native DevSecOps orchestration layer. "
        "Aggregates security signals from Semgrep, Trivy, Grype, Falco, "
        "Kyverno, Prometheus, OTel and provides AI-driven risk scoring, "
        "consensus decisions, and auto-remediation."
    ),
    version=settings.VERSION,
    lifespan=lifespan,
)

# Prometheus instrumentation
Instrumentator(
    should_group_status_codes=True,
    should_ignore_untemplated=True,
    excluded_handlers=["/healthz", "/readyz", "/metrics"],
).instrument(app).expose(app, endpoint="/metrics")

# Register routers
app.include_router(risk_router, prefix="/api/v1/risk", tags=["Risk Engine"])
app.include_router(consensus_router, prefix="/api/v1/consensus", tags=["Consensus Engine"])
app.include_router(decision_router, prefix="/api/v1/decision", tags=["Decision Engine"])
app.include_router(planner_router, prefix="/api/v1/agents/planner", tags=["AI Planner"])
app.include_router(threat_router, prefix="/api/v1/agents/threat", tags=["Threat Modeling"])
app.include_router(code_review_router, prefix="/api/v1/agents/code-review", tags=["Code Review"])
app.include_router(docker_audit_router, prefix="/api/v1/agents/docker-audit", tags=["Docker Audit"])
app.include_router(k8s_audit_router, prefix="/api/v1/agents/k8s-audit", tags=["K8s Audit"])
app.include_router(runtime_router, prefix="/api/v1/agents/runtime", tags=["Runtime Security"])
app.include_router(metrics_router, prefix="/api/v1/agents/metrics", tags=["Metrics Analyzer"])
app.include_router(report_router, prefix="/api/v1/agents/report", tags=["Report Generator"])
app.include_router(deployment_validator_router, prefix="/api/v1/validators/deployment", tags=["Deployment Validator"])
app.include_router(runtime_validator_router, prefix="/api/v1/validators/runtime", tags=["Runtime Validator"])


@app.get("/healthz")
async def healthz():
    """Kubernetes liveness probe."""
    return {"status": "ok", "service": "ai-security-orchestrator", "version": settings.VERSION}


@app.get("/readyz")
async def readyz():
    """Kubernetes readiness probe."""
    return {
        "status": "ok",
        "event_bus": event_bus.is_running,
        "agents_registered": len(app.routes),
    }
