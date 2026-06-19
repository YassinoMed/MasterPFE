import os
import logging
import httpx
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func

from .db import init_db, get_db
from .models import AnalysisResult, SecurityIncident
from .schemas import (
    AnalysisResultCreate,
    AnalysisResultOut,
    SecurityIncidentOut,
    SecurityIncidentUpdate,
    DashboardStats
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-backend")

app = FastAPI(
    title="AI Security Backend API",
    description="Backend API for AI-Driven DevSecOps platform with WebSockets support.",
    version="0.1.0"
)

# Enable CORS for frontend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

INFERENCE_SERVICE_URL = os.getenv("INFERENCE_SERVICE_URL", "http://localhost:8000")


@app.on_event("startup")
def on_startup():
    init_db()
    from prometheus_fastapi_instrumentator import Instrumentator
    Instrumentator().instrument(app).expose(app)
    logger.info("Database and Prometheus instrumentation initialized.")


# ── WebSocket Manager ─────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"New client connected. Active connections: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        logger.info(f"Client disconnected. Active connections: {len(self.active_connections)}")

    async def broadcast(self, message: Dict[str, Any]):
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.error(f"Error sending message to websocket: {e}")
                # We do not disconnect here to avoid altering list during iteration.


manager = ConnectionManager()


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # Maintain connection alive, ignore incoming messages
            data = await websocket.receive_text()
            logger.debug(f"Received text from WS client: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)


# ── REST API Endpoints ────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "service": "ai-security-backend"}


@app.post("/analyze", response_model=AnalysisResultOut)
async def analyze_log(payload: AnalysisResultCreate, db: Session = Depends(get_db)):
    """
    Proxies log analysis to the AI Inference Service.
    Persists result in database, auto-triggers incidents for MALICIOUS findings,
    broadcasts alerts to WebSocket clients, and returns the result.
    """
    analysis_data = None
    # 1. Forward request to inference service
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                f"{INFERENCE_SERVICE_URL}/analyze",
                json={"source": payload.source, "log": payload.raw_log}
            )
            if resp.status_code == 200:
                analysis_data = resp.json()
            else:
                logger.warning(f"Inference service returned status {resp.status_code}. Using local heuristics.")
    except Exception as e:
        logger.warning(f"Failed to connect to inference service at {INFERENCE_SERVICE_URL}: {e}. Using local fallback.")

    # 2. Local Fallback Heuristics in case inference service is unreachable
    if not analysis_data:
        try:
            import sys
            from pathlib import Path
            parent_dir = str(Path(__file__).resolve().parent.parent)
            if parent_dir not in sys.path:
                sys.path.insert(0, parent_dir)
            from app import heuristic_analyze
            analysis_data = heuristic_analyze(payload.source, payload.raw_log)
        except Exception as e:
            logger.error(f"Failed to load heuristics fallback: {e}")
            analysis_data = {
                "classification": "SUSPICIOUS",
                "confidence": 50.0,
                "severity": "MEDIUM",
                "explanation": f"Failed to analyze log. Exception: {e}",
                "recommendation": "Review logs manually."
            }

    # 3. Save to database
    db_result = AnalysisResult(
        source=payload.source,
        raw_log=payload.raw_log,
        classification=analysis_data["classification"],
        confidence=analysis_data["confidence"],
        severity=analysis_data["severity"],
        explanation=analysis_data["explanation"],
        recommendation=analysis_data["recommendation"]
    )
    db.add(db_result)
    db.commit()
    db.refresh(db_result)

    # 4. Auto-generate incident if Malicious
    incident_created = False
    incident_id = None
    if db_result.classification == "MALICIOUS":
        incident = SecurityIncident(
            source=db_result.source,
            severity=db_result.severity,
            confidence=db_result.confidence,
            description=db_result.explanation,
            recommendation=db_result.recommendation,
            status="OPEN"
        )
        db.add(incident)
        db.commit()
        db.refresh(incident)
        incident_created = True
        incident_id = incident.id

    # 5. Broadcast to websocket clients in real-time
    ws_payload = {
        "event_type": "NEW_ANALYSIS",
        "data": {
            "id": db_result.id,
            "timestamp": db_result.timestamp.isoformat(),
            "source": db_result.source,
            "classification": db_result.classification,
            "severity": db_result.severity,
            "confidence": db_result.confidence,
            "explanation": db_result.explanation,
            "recommendation": db_result.recommendation,
            "raw_log": db_result.raw_log
        },
        "incident_created": incident_created,
        "incident_id": incident_id
    }
    await manager.broadcast(ws_payload)

    return db_result


@app.get("/logs", response_model=List[AnalysisResultOut])
def get_logs(
    source: Optional[str] = None,  # type: ignore[name-defined]
    classification: Optional[str] = None,  # type: ignore[name-defined]
    severity: Optional[str] = None,  # type: ignore[name-defined]
    limit: int = 100,
    db: Session = Depends(get_db)
):
    query = db.query(AnalysisResult)
    if source:
        query = query.filter(AnalysisResult.source == source)
    if classification:
        query = query.filter(AnalysisResult.classification == classification)
    if severity:
        query = query.filter(AnalysisResult.severity == severity)
    return query.order_by(AnalysisResult.timestamp.desc()).limit(limit).all()


@app.get("/alerts", response_model=List[AnalysisResultOut])
def get_alerts(limit: int = 50, db: Session = Depends(get_db)):
    """Returns suspicious or malicious logs."""
    return db.query(AnalysisResult).filter(
        AnalysisResult.classification.in_(["SUSPICIOUS", "MALICIOUS"])
    ).order_by(AnalysisResult.timestamp.desc()).limit(limit).all()


@app.get("/incidents", response_model=List[SecurityIncidentOut])
def get_incidents(status: Optional[str] = None, limit: int = 50, db: Session = Depends(get_db)):  # type: ignore[name-defined]
    query = db.query(SecurityIncident)
    if status:
        query = query.filter(SecurityIncident.status == status)
    return query.order_by(SecurityIncident.timestamp.desc()).limit(limit).all()


@app.put("/incidents/{incident_id}/status", response_model=SecurityIncidentOut)
def update_incident_status(incident_id: int, payload: SecurityIncidentUpdate, db: Session = Depends(get_db)):
    incident = db.query(SecurityIncident).filter(SecurityIncident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    incident.status = payload.status
    db.commit()
    db.refresh(incident)
    return incident


@app.get("/sources", response_model=List[str])
def get_sources(db: Session = Depends(get_db)):
    results = db.query(AnalysisResult.source).distinct().all()
    return [r[0] for r in results if r[0]]


@app.get("/statistics")
def get_statistics(db: Session = Depends(get_db)):
    """Provides grouped stats for charts."""
    class_stats = db.query(AnalysisResult.classification, func.count(AnalysisResult.id)).group_by(AnalysisResult.classification).all()
    severity_stats = db.query(AnalysisResult.severity, func.count(AnalysisResult.id)).group_by(AnalysisResult.severity).all()
    source_stats = db.query(AnalysisResult.source, func.count(AnalysisResult.id)).group_by(AnalysisResult.source).all()

    return {
        "classifications": {c: count for c, count in class_stats},
        "severities": {s: count for s, count in severity_stats},
        "sources": {src: count for src, count in source_stats}
    }


@app.get("/dashboard", response_model=DashboardStats)
def get_dashboard_summary(db: Session = Depends(get_db)):
    total = db.query(func.count(AnalysisResult.id)).scalar() or 0
    malicious = db.query(func.count(AnalysisResult.id)).filter(AnalysisResult.classification == "MALICIOUS").scalar() or 0
    suspicious = db.query(func.count(AnalysisResult.id)).filter(AnalysisResult.classification == "SUSPICIOUS").scalar() or 0

    detection_rate = (malicious + suspicious) / total * 100 if total > 0 else 0.0

    # Calculate overall risk score (scale of 0-100)
    # Higher counts of malicious and suspicious events boost risk
    risk_score = min(100.0, (malicious * 15.0 + suspicious * 5.0))

    critical_alerts = db.query(AnalysisResult).filter(
        AnalysisResult.severity.in_(["HIGH", "CRITICAL"])
    ).order_by(AnalysisResult.timestamp.desc()).limit(5).all()

    # Top sources query
    source_counts = db.query(AnalysisResult.source, func.count(AnalysisResult.id)).group_by(AnalysisResult.source).order_by(func.count(AnalysisResult.id).desc()).limit(5).all()
    top_sources = [{"source": src, "count": cnt} for src, cnt in source_counts]

    return DashboardStats(
        total_events=total,
        malicious_events=malicious,
        suspicious_events=suspicious,
        global_risk_score=risk_score,
        detection_rate=detection_rate,
        critical_alerts=[AnalysisResultOut.model_validate(c) for c in critical_alerts],
        top_sources=top_sources
    )
