# ─────────────────────────────────────────────────
# SECAI — Security AI Layer (read-only analysis)
# ─────────────────────────────────────────────────
FROM python:3.13-slim-bookworm AS secai-runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    SECAI_MODEL_CACHE_DIR=/app/model-cache \
    SECAI_MODEL_ID=cisco-ai/SecureBERT2.0-base \
    SECAI_DEVICE=auto \
    SECAI_MAX_LENGTH=1024

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN groupadd --gid 10001 secai && \
    useradd --uid 10001 --gid 10001 --create-home secai

WORKDIR /app

# Dependencies
COPY secai/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt --index-url https://download.pytorch.org/whl/cpu 2>/dev/null || pip install --no-cache-dir -r requirements.txt

# SECAI package at /app/secai/
COPY secai/ /app/secai/

# Model-cache dir
RUN mkdir -p /app/model-cache && \
    chown -R secai:secai /app

USER secai

EXPOSE 8001

CMD ["uvicorn", "secai.api.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8001", \
     "--workers", "1"]
