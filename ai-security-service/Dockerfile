# ─────────────────────────────────────────────────────────────────
# SecureRAG Hub — AI Security Service
# Multi-stage production Dockerfile
# ─────────────────────────────────────────────────────────────────
# Stage 1: Build dependencies
FROM python:3.11-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Build dependencies for llama-cpp-python (C++ compilation)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

# ─────────────────────────────────────────────────────────────────
# Stage 2: Production runtime
FROM python:3.11-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Model cache directories
    MODEL_CACHE_DIR=/app/model-cache \
    HF_HOME=/app/model-cache/huggingface \
    TRANSFORMERS_CACHE=/app/model-cache/huggingface/hub

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /install /usr/local

# Create non-root user
RUN groupadd --gid 10001 appuser && \
    useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin appuser

WORKDIR /app

# Copy application code
COPY --chown=appuser:appuser . .

# Create model cache directory
RUN mkdir -p /app/model-cache/huggingface/hub /app/models && \
    chown -R appuser:appuser /app/model-cache /app/models

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Switch to non-root user
USER appuser

EXPOSE 8000

# Uvicorn with production settings
CMD ["uvicorn", "api.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "1", \
     "--timeout-keep-alive", "30", \
     "--access-log"]
