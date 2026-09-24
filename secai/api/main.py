"""SECAI — FastAPI skeletal (read-only — no mutations)."""
from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, Body, Request
from pydantic import BaseModel, ValidationError

from secai.api.schemas import Finding, Decision
from secai.config import get_settings
from secai.models import SecureBERTLoader, ModelNotAvailable
from secai.pipelines.alert_correlation import correlate, cluster_summary
from secai.pipelines.security_analysis import analyze_reports

logger = logging.getLogger("secai.api")
settings = get_settings()


class HealthResponse(BaseModel):
    status: str
    service: str = "secai"
    model_loaded: bool
    model_id: str


class ReadyResponse(BaseModel):
    ready: bool
    detail: str = ""


class AnalyzeResponse(BaseModel):
    findings_count: int
    verdict: str
    severity_distribution: dict[str, int]
    top_findings: list[dict]


class ExplainRequest(BaseModel):
    finding_id: str | None = None
    source: str | None = None
    rule_id: str | None = None
    message: str | None = None
    severity: str | None = None


secure_heuristics_available = True


@asynccontextmanager
async def lifespan(_: FastAPI):
    """Never block the API on model download: run ACAI error codes independently.
    The startup probe can answer ready immediately, while the model loads in background."""
    import asyncio
    async def _load_model():
        try:
            await asyncio.to_thread(SecureBERTLoader.load)
        except ModelNotAvailable as exc:
            logger.warning("secai: model smart loader degraded: %s", type(exc).__name__)
        except Exception as exc:
            logger.warning("secai: unexpected: %s", type(exc).__name__)
    # Start loading in the background without blocking FastAPI's startup.
    asyncio.create_task(_load_model())
    logger.info("SECAI API lifecycle started (model will load in background)")
    yield


app = FastAPI(title="SecureRAG Hub — SECAI API", version="0.1.0", lifespan=lifespan)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        model_loaded=SecureBERTLoader._model is not None,
        model_id=settings.MODEL_ID,
    )


@app.get("/ready", response_model=ReadyResponse)
def ready() -> ReadyResponse:
    ready_flag = True  # pipeline works also heuristics-only
    detail = "model loaded" if SecureBERTLoader._model else "degraded mode (no ML)"
    return ReadyResponse(ready=ready_flag, detail=detail)


_ALLOWED_PREFIX = Path.cwd()


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(payload: dict = Body(...)) -> AnalyzeResponse:
    reports: list[str] = payload.get("reports", []) or []
    if not isinstance(reports, list) or len(reports) > 50:
        raise HTTPException(status_code=400, detail="trop de rapports")

    paths: list[Path] = []
    for rp in reports:
        p = Path(rp).resolve(strict=False)
        if not str(p).startswith(str(_ALLOWED_PREFIX)):
            raise HTTPException(status_code=403, detail="chemin hors workspace")
        paths.append(p)

    report = analyze_reports(paths, image_names=payload.get("images"))
    top = sorted(report.findings, key=lambda f: f.risk_score, reverse=True)[:10]
    return AnalyzeResponse(
        findings_count=report.summary.total_findings,
        verdict=report.summary.verdict.value,
        severity_distribution=report.summary.by_severity,
        top_findings=[
            {
                "finding_id": f.finding_id,
                "source": f.source.value,
                "severity": f.severity.value,
                "title": f.title,
                "explanation": f.explanation,
                "requires_human_review": f.requires_human_review,
            }
            for f in top
        ],
    )


@app.post("/correlate")
def correlate_api(payload: dict = Body(...)) -> dict:
    reports: list[str] = payload.get("reports", []) or []
    if not isinstance(reports, list) or len(reports) > 50:
        raise HTTPException(status_code=400, detail="trop de rapports")
    paths = [Path(p).resolve(strict=False) for p in reports]
    for p in paths:
        if not str(p).startswith(str(_ALLOWED_PREFIX)):
            raise HTTPException(status_code=403, detail="chemin hors workspace")
    report = analyze_reports(paths)
    return cluster_summary(correlate(report.findings))


@app.post("/explain")
def explain_api(payload: ExplainRequest) -> dict:
    """Réponse narrative. Toujours marquée 'human review'."""
    import html as html_mod
    msg = payload.message or "No details provided"
    safe = html_mod.escape(msg[:300], quote=True)
    return {
        "finding_id": payload.finding_id,
        "category": payload.rule_id or "unknown",
        "explanation": safe,
        "requires_human_review": True,
    }


@app.get("/models")
def models_info() -> dict:
    return {
        "model_id": settings.MODEL_ID,
        "base_model": "cisco-ai/SecureBERT2.0-base",
        "note": "Encodeur uniquement (embeddings) — aucune prédiction supervisée de classe",
        "device": (
            str(SecureBERTLoader._device.type)
            if SecureBERTLoader._device is not None
            else "not_loaded"
        ),
    }
