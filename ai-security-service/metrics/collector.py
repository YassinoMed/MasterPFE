"""
Prometheus Metrics Collector for AI Security Pipeline.

Exposes all required counters, histograms, and gauges for the four-layer
AI security pipeline, consumed by Prometheus and visualised in Grafana.
"""

from prometheus_client import Counter, Histogram, Gauge, Info

# ── Layer 1: Prompt Injection Metrics ──────────────────────────
PROMPT_INJECTION_TOTAL = Counter(
    "prompt_injection_total",
    "Total number of prompt injection attempts detected",
    ["classification"],  # safe, suspicious, malicious
)

# ── Layer 2: Jailbreak Detection Metrics ───────────────────────
JAILBREAK_DETECTED_TOTAL = Counter(
    "jailbreak_detected_total",
    "Total number of jailbreak attempts detected",
    ["classification"],  # allow, review, deny
)

# ── Pipeline Decision Metrics ──────────────────────────────────
BLOCKED_REQUESTS_TOTAL = Counter(
    "blocked_requests_total",
    "Total number of blocked requests",
    ["reason"],  # injection, jailbreak
)

ALLOWED_REQUESTS_TOTAL = Counter(
    "allowed_requests_total",
    "Total number of allowed requests",
)

# ── Layer 3: Routing Metrics ───────────────────────────────────
ROUTING_LATENCY = Histogram(
    "routing_latency_seconds",
    "Latency of the semantic routing layer",
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0),
)

ROUTING_DECISIONS = Counter(
    "routing_decisions_total",
    "Total routing decisions by category and model",
    ["category", "model"],
)

# ── Layer 4: Model Inference Metrics ───────────────────────────
MODEL_LATENCY = Histogram(
    "model_latency_seconds",
    "Latency of expert AI model inference",
    ["model_name"],
    buckets=(0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0),
)

MODEL_ERRORS = Counter(
    "model_errors_total",
    "Total errors encountered during model inference",
    ["model_name"],
)

TOKENS_PROCESSED = Counter(
    "tokens_processed_total",
    "Total tokens processed by expert models",
    ["model_name"],
)

# ── Pipeline-level Metrics ─────────────────────────────────────
PIPELINE_DURATION = Histogram(
    "pipeline_duration_seconds",
    "Total end-to-end pipeline duration",
    buckets=(0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0),
)

# ── MLOps / Resource Metrics ───────────────────────────────────
MODEL_MEMORY_USAGE = Gauge(
    "model_memory_usage_bytes",
    "Current memory usage by model",
    ["model_name"],
)

MODEL_VRAM_USAGE = Gauge(
    "model_vram_usage_bytes",
    "Current VRAM usage (GPU)",
)

MODEL_INFO = Info(
    "ai_security_service",
    "AI Security Service metadata",
)

# ── Convenience Functions ──────────────────────────────────────


def record_prompt_injection(classification: str) -> None:
    """Record a prompt injection detection event."""
    PROMPT_INJECTION_TOTAL.labels(classification=classification).inc()


def record_jailbreak(classification: str) -> None:
    """Record a jailbreak detection event."""
    JAILBREAK_DETECTED_TOTAL.labels(classification=classification).inc()


def record_blocked_request(reason: str = "injection") -> None:
    """Record a blocked request."""
    BLOCKED_REQUESTS_TOTAL.labels(reason=reason).inc()


def record_allowed_request() -> None:
    """Record an allowed request."""
    ALLOWED_REQUESTS_TOTAL.inc()


def record_routing_decision(category: str, model: str) -> None:
    """Record a routing decision."""
    ROUTING_DECISIONS.labels(category=category, model=model).inc()


def record_model_error(model_name: str) -> None:
    """Record a model inference error."""
    MODEL_ERRORS.labels(model_name=model_name).inc()


def record_tokens(model_name: str, token_count: int) -> None:
    """Record tokens processed."""
    TOKENS_PROCESSED.labels(model_name=model_name).inc(token_count)


def update_memory_metrics(model_name: str, memory_bytes: float) -> None:
    """Update memory usage gauge for a model."""
    MODEL_MEMORY_USAGE.labels(model_name=model_name).set(memory_bytes)


def update_vram_metrics(vram_bytes: float) -> None:
    """Update VRAM usage gauge."""
    MODEL_VRAM_USAGE.set(vram_bytes)


def set_service_info(version: str, environment: str) -> None:
    """Set service metadata."""
    MODEL_INFO.info({
        "version": version,
        "environment": environment,
    })
