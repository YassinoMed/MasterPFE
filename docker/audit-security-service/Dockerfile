# ==========================================
# Étape 1 : Builder (installation des dépendances)
# ==========================================
FROM python:3.11-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VENV_PATH=/opt/venv

RUN python -m venv "${VENV_PATH}"
ENV PATH="${VENV_PATH}/bin:${PATH}"

WORKDIR /app

# Copier le fichier de dépendances
COPY services/security-auditor/requirements.txt ./

# Mettre à jour pip et installer les dépendances dans le virtualenv
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

# ==========================================
# Étape 2 : Image de production finale (runtime)
# ==========================================
FROM gcr.io/distroless/python3-debian12:latest
WORKDIR /app

# Ajouter les LABEL OCI standard
LABEL org.opencontainers.image.title="SecureRAG Hub Audit Security Service" \
      org.opencontainers.image.description="Hardened Python FastAPI runtime for prompt injection auditing" \
      org.opencontainers.image.source="https://github.com/YassinoMed/MasterPFE" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Google DeepMind Advanced Agentic Coding"

# Définir l'environnement Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv \
    PORT=8080 \
    SERVICE_NAME=security-auditor

# Configurer le PATH pour inclure le virtualenv
ENV PATH="${VENV_PATH}/bin:${PATH}"
# Configurer le PYTHONPATH pour charger les dépendances du virtualenv
ENV PYTHONPATH="${VENV_PATH}/lib/python3.11/site-packages"

# Copier le virtualenv depuis le builder avec les bons droits non-root
COPY --chown=10001:10001 --from=builder /opt/venv /opt/venv

# Copier le code source de l'application
COPY --chown=10001:10001 services/security-auditor/src ./src

# Exposer le port de service
EXPOSE 8080

# Exécuter en tant qu'utilisateur non-root 10001 (PSS Restricted)
USER 10001:10001

# Lancer l'application FastAPI via Uvicorn
ENTRYPOINT ["/usr/bin/python3", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
