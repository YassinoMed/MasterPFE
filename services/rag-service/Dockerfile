# syntax=docker/dockerfile:1
# SecureRAG Hub — RAG Service (Google Distroless Multi-stage)

# ==============================================================================
# STAGE 1: Builder (Compilation des dépendances Python via 'uv')
# ==============================================================================
FROM python:3.12-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_SYSTEM_PYTHON=0 \
    UV_LINK_MODE=copy

WORKDIR /build

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY requirements.txt ./

RUN uv venv /app/.venv && \
    uv pip install --no-cache -r requirements.txt

# ==============================================================================
# STAGE 2: Runtime Minimal (Google Distroless - Zero Shell / Rootless)
# ==============================================================================
FROM gcr.io/distroless/python3-debian12:nonroot AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH" \
    PYTHONPATH="/app/app" \
    PORT=8000 \
    SERVICE_NAME=rag-service

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --chown=nonroot:nonroot app /app/app

EXPOSE 8000

USER 65532:65532

ENTRYPOINT ["/app/.venv/bin/python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
