"""
SecureRAG Hub — AI Security Service.

Central FastAPI application implementing the 4-layer AI security pipeline:

    Layer 1: Prompt Injection Detection  (protectai/deberta-v3-small)
    Layer 2: Jailbreak Detection         (mmbert32k-jailbreak-detector)
    Layer 3: Semantic Routing            (TF-IDF category matching)
    Layer 4: Expert AI Models            (Seneca GGUF / DevOps Mastermind)

All user queries must traverse all four layers sequentially.
No query reaches an LLM without prior security validation.
"""

import json
import logging
import os
import time
from contextlib import asynccontextmanager
from typing import Any, Dict, Optional

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field
from prometheus_fastapi_instrumentator import Instrumentator

from config.config import get_settings
from models.prompt_injection import PromptInjectionDetector
from models.jailbreak_detector import JailbreakDetector
from models.cybersecurity_agent import CyberSecurityAgent
from models.devops_agent import DevOpsAgent
from routing.semantic_router import SemanticRouter
from security.guardrails import apply_guardrails
from services.model_registry import ModelRegistry
from metrics.collector import (
    record_prompt_injection,
    record_jailbreak,
    record_blocked_request,
    record_allowed_request,
    record_routing_decision,
    record_model_error,
    record_tokens,
    set_service_info,
    ROUTING_LATENCY,
    MODEL_LATENCY,
    PIPELINE_DURATION,
)


# ── Structured JSON Logging (Loki-compatible) ─────────────────

class LokiJSONFormatter(logging.Formatter):
    """JSON log formatter compatible with Grafana Loki / Promtail."""

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": "ai-security-service",
        }
        # Merge extra structured fields (trace_id, user, etc.)
        if hasattr(record, "extra_info") and isinstance(record.extra_info, dict):
            log_entry.update(record.extra_info)
        return json.dumps(log_entry, default=str)


# Configure root logger
handler = logging.StreamHandler()
handler.setFormatter(LokiJSONFormatter())
logging.basicConfig(
    level=getattr(logging, get_settings().LOG_LEVEL, logging.INFO),
    handlers=[handler],
    force=True,
)
logger = logging.getLogger("ai-security-pipeline")


# ── Global Model Instances ─────────────────────────────────────
# Initialised during application lifespan startup.
registry = ModelRegistry()
pi_detector: Optional[PromptInjectionDetector] = None
jb_detector: Optional[JailbreakDetector] = None
semantic_router: Optional[SemanticRouter] = None
cyber_agent: Optional[CyberSecurityAgent] = None
devops_agent: Optional[DevOpsAgent] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle: load models on startup, cleanup on shutdown."""
    global pi_detector, jb_detector, semantic_router, cyber_agent, devops_agent

    settings = get_settings()
    logger.info("Starting AI Security Service v%s (%s)", settings.VERSION, settings.ENVIRONMENT)

    # Set HuggingFace cache directory
    os.environ["HF_HOME"] = settings.HF_HOME
    os.environ["TRANSFORMERS_CACHE"] = os.path.join(settings.HF_HOME, "hub")

    # ── Initialise Layer 1: Prompt Injection Detector ──────
    logger.info("Loading Layer 1: Prompt Injection Detector...")
    pi_detector = PromptInjectionDetector(
        model_name=settings.PI_MODEL_NAME,
        max_length=settings.PI_MAX_LENGTH,
        suspicious_threshold=settings.PI_SUSPICIOUS_THRESHOLD,
        malicious_threshold=settings.PI_MALICIOUS_THRESHOLD,
    )
    registry.register(
        "PromptInjectionDetector", pi_detector,
        version="2.0.0", model_type="classifier",
        source=settings.PI_MODEL_NAME,
    )

    # ── Initialise Layer 2: Jailbreak Detector ─────────────
    logger.info("Loading Layer 2: Jailbreak Detector...")
    jb_detector = JailbreakDetector(
        model_name=settings.JB_MODEL_NAME,
        max_length=settings.JB_MAX_LENGTH,
        review_threshold=settings.JB_REVIEW_THRESHOLD,
        deny_threshold=settings.JB_DENY_THRESHOLD,
    )
    registry.register(
        "JailbreakDetector", jb_detector,
        version="2.0.0", model_type="classifier",
        source=settings.JB_MODEL_NAME,
    )

    # ── Initialise Layer 3: Semantic Router ────────────────
    logger.info("Loading Layer 3: Semantic Router...")
    semantic_router = SemanticRouter()

    # ── Initialise Layer 4a: CyberSecurity Agent ───────────
    logger.info("Loading Layer 4a: CyberSecurity Agent...")
    cyber_agent = CyberSecurityAgent(
        model_path=settings.CYBER_MODEL_PATH,
        n_ctx=settings.CYBER_CTX_SIZE,
        max_tokens=settings.CYBER_MAX_TOKENS,
        n_threads=settings.CYBER_THREADS,
        n_gpu_layers=settings.CYBER_GPU_LAYERS,
    )
    registry.register(
        "CyberSecurityAgent", cyber_agent,
        version="2.0.0", model_type="gguf",
        source="AlicanKiraz0/Seneca-Cybersecurity-LLM-Q4_K_M-GGUF",
    )

    # ── Initialise Layer 4b: DevOps Agent ──────────────────
    logger.info("Loading Layer 4b: DevOps Agent...")
    devops_agent = DevOpsAgent(
        model_name=settings.DEVOPS_MODEL_NAME,
        max_tokens=settings.DEVOPS_MAX_TOKENS,
    )
    registry.register(
        "DevOpsAgent", devops_agent,
        version="2.0.0", model_type="generator",
        source=settings.DEVOPS_MODEL_NAME,
    )

    # ── Warmup all models ──────────────────────────────────
    logger.info("Running model warmup...")
    warmup_times = registry.warmup_all()
    logger.info("Model warmup complete: %s", warmup_times)

    # ── Set Prometheus metadata ────────────────────────────
    set_service_info(settings.VERSION, settings.ENVIRONMENT)

    logger.info("All 4 layers initialised. AI Security Service is ready.")

    yield  # ── Application running ────────────────────────

    logger.info("Shutting down AI Security Service...")


# ── FastAPI Application ────────────────────────────────────────

app = FastAPI(
    title="SecureRAG Hub — AI Security Service",
    description=(
        "4-layer AI security pipeline: Prompt Injection Detection → "
        "Jailbreak Detection → Semantic Routing → Expert AI Models. "
        "All queries are validated before reaching any LLM."
    ),
    version=get_settings().VERSION,
    lifespan=lifespan,
)

# Prometheus auto-instrumentation
Instrumentator(
    should_group_status_codes=True,
    should_ignore_untemplated=True,
    excluded_handlers=["/health", "/readyz", "/metrics"],
).instrument(app).expose(app, endpoint="/metrics")


# ── Request / Response Models ──────────────────────────────────

class QueryRequest(BaseModel):
    """User query input."""
    prompt: str = Field(..., min_length=1, max_length=4096, description="User prompt to analyse")
    user: str = Field(default="anonymous", description="Username for audit logging")
    namespace: str = Field(default="default", description="Kubernetes namespace context")


class QueryResponse(BaseModel):
    """Pipeline response output."""
    response: str
    model_used: str
    category: str
    trace_id: str
    inference_time_ms: float
    pi_classification: str
    jb_classification: str


class HealthResponse(BaseModel):
    """Health check response."""
    status: str
    version: str
    models: Dict[str, Any]


# ── Middleware ─────────────────────────────────────────────────

@app.middleware("http")
async def trace_id_middleware(request: Request, call_next):
    """Inject or propagate X-Trace-Id for distributed tracing."""
    trace_id = request.headers.get("X-Trace-Id", os.urandom(8).hex())
    request.state.trace_id = trace_id
    response = await call_next(request)
    response.headers["X-Trace-Id"] = trace_id
    return response


# ── Main Pipeline Endpoint ─────────────────────────────────────

@app.post("/api/v1/query", response_model=QueryResponse)
async def process_query(request: QueryRequest, req: Request):
    """
    Process a user query through the 4-layer AI security pipeline.

    Layer 1: Prompt Injection Detection → blocks malicious prompts (HTTP 403)
    Layer 2: Jailbreak Detection → blocks jailbreak attempts (HTTP 403)
    Layer 3: Semantic Routing → selects the appropriate expert model
    Layer 4: Expert AI Model → generates the response
    Layer 5: Guardrails → sanitises the output
    """
    trace_id = req.state.trace_id
    pipeline_start = time.time()

    # Structured log payload for Loki
    log_payload = {
        "trace_id": trace_id,
        "user": request.user,
        "namespace": request.namespace,
        "prompt_length": len(request.prompt),
    }

    try:
        # ══════════════════════════════════════════════════════
        # Layer 1: Prompt Injection Detection
        # ══════════════════════════════════════════════════════
        pi_result = pi_detector.detect(request.prompt)
        pi_class = pi_result["classification"]
        log_payload["pi_classification"] = pi_class
        log_payload["pi_confidence"] = pi_result["confidence"]
        log_payload["pi_inference_ms"] = pi_result["inference_time_ms"]

        record_prompt_injection(pi_class)

        if pi_class == "malicious":
            record_blocked_request("injection")
            logger.warning(
                "BLOCKED: Prompt injection detected",
                extra={"extra_info": log_payload},
            )
            raise HTTPException(
                status_code=403,
                detail={
                    "error": "Prompt blocked by security layer",
                    "layer": "PromptInjectionDetector",
                    "classification": pi_class,
                    "confidence": pi_result["confidence"],
                    "trace_id": trace_id,
                },
            )

        # ══════════════════════════════════════════════════════
        # Layer 2: Jailbreak Detection
        # ══════════════════════════════════════════════════════
        jb_result = jb_detector.detect(request.prompt)
        jb_class = jb_result["classification"]
        log_payload["jb_classification"] = jb_class
        log_payload["jb_confidence"] = jb_result["confidence"]
        log_payload["jb_attack_types"] = jb_result.get("attack_types", [])
        log_payload["jb_inference_ms"] = jb_result["inference_time_ms"]

        record_jailbreak(jb_class)

        if jb_class == "deny":
            record_blocked_request("jailbreak")
            logger.warning(
                "BLOCKED: Jailbreak attempt detected",
                extra={"extra_info": log_payload},
            )
            raise HTTPException(
                status_code=403,
                detail={
                    "error": "Prompt blocked by security layer",
                    "layer": "JailbreakDetector",
                    "classification": jb_class,
                    "attack_types": jb_result.get("attack_types", []),
                    "confidence": jb_result["confidence"],
                    "trace_id": trace_id,
                },
            )

        # Both layers passed → allowed
        record_allowed_request()

        # ══════════════════════════════════════════════════════
        # Layer 3: Semantic Routing
        # ══════════════════════════════════════════════════════
        routing_start = time.time()
        routing_result = semantic_router.route_detailed(request.prompt)
        routing_elapsed = time.time() - routing_start
        ROUTING_LATENCY.observe(routing_elapsed)

        chosen_model = routing_result["model"]
        chosen_category = routing_result["category"]
        log_payload["model_chosen"] = chosen_model
        log_payload["category"] = chosen_category
        log_payload["routing_confidence"] = routing_result["confidence"]

        record_routing_decision(chosen_category, chosen_model)

        # ══════════════════════════════════════════════════════
        # Layer 4: Expert Model Inference
        # ══════════════════════════════════════════════════════
        model_start = time.time()

        if chosen_model == "CyberSecurityAgent":
            response_text = cyber_agent.generate_response(request.prompt)
        else:
            response_text = devops_agent.generate_response(request.prompt)

        model_elapsed = time.time() - model_start
        MODEL_LATENCY.labels(model_name=chosen_model).observe(model_elapsed)

        # Record inference in registry
        registry.record_inference(chosen_model)

        # Approximate token count for metrics
        tokens = len(request.prompt.split()) + len(response_text.split())
        record_tokens(chosen_model, tokens)

        # ══════════════════════════════════════════════════════
        # Layer 5: Guardrails (Output Safety)
        # ══════════════════════════════════════════════════════
        settings = get_settings()
        if settings.GUARDRAILS_ENABLED:
            safe_response = apply_guardrails(response_text)
        else:
            safe_response = response_text

        # ── Final logging ──────────────────────────────────
        total_ms = (time.time() - pipeline_start) * 1000
        PIPELINE_DURATION.observe(total_ms / 1000)

        log_payload["inference_time_ms"] = round(total_ms, 2)
        log_payload["decision"] = "allowed"
        log_payload["tokens_processed"] = tokens

        logger.info(
            "Request processed successfully",
            extra={"extra_info": log_payload},
        )

        return QueryResponse(
            response=safe_response,
            model_used=chosen_model,
            category=chosen_category,
            trace_id=trace_id,
            inference_time_ms=round(total_ms, 2),
            pi_classification=pi_class,
            jb_classification=jb_class,
        )

    except HTTPException:
        raise
    except Exception as exc:
        record_model_error("pipeline")
        log_payload["error"] = str(exc)
        logger.error(
            "Pipeline error: %s", exc,
            extra={"extra_info": log_payload},
        )
        raise HTTPException(
            status_code=500,
            detail={
                "error": "Internal AI Pipeline Error",
                "trace_id": trace_id,
            },
        )


# ── Health & Readiness Endpoints ───────────────────────────────

@app.get("/health")
def health_check():
    """Kubernetes liveness probe."""
    return {
        "status": "ok",
        "service": "ai-security-service",
        "version": get_settings().VERSION,
    }


@app.get("/readyz", response_model=HealthResponse)
def readiness_check():
    """Kubernetes readiness probe — verifies all models are loaded."""
    health = registry.health_check()
    status = "ok" if health["status"] == "healthy" else "degraded"

    return HealthResponse(
        status=status,
        version=get_settings().VERSION,
        models=health["models"],
    )


# ── MLOps Endpoints ────────────────────────────────────────────

@app.get("/api/v1/models")
def list_models():
    """List all registered models with versions and status."""
    return {
        "models": registry.get_versions(),
        "health": registry.health_check(),
    }


@app.get("/api/v1/models/stats")
def model_statistics():
    """Return inference statistics for all models."""
    return registry.get_statistics()


@app.get("/api/v1/resources")
def resource_usage():
    """Return current resource usage (CPU, RAM, VRAM)."""
    return registry.get_resource_usage()


@app.get("/api/v1/routes")
def list_routes():
    """List all semantic routing categories."""
    if semantic_router:
        return {"categories": semantic_router.get_categories()}
    return {"categories": []}
