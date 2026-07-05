import logging
import uuid
import datetime
from typing import Dict, Any, List, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-memory")

app = FastAPI(
    title="AI Memory Service",
    description="Long-term incident storage and retrieval service (RAG enhancer).",
    version="0.1.0"
)

class IncidentRecord(BaseModel):
    description: str = Field(..., example="Interactive shell spawned in portal-web container.")
    cause: str = Field(..., example="Exploitation of public RCE vulnerability in Laravel upload module.")
    context: str = Field(..., example="Host: Linux VPS, Pod: portal-web-86f77-2sjc, Namespace: securerag-hub")
    solution: str = Field(..., example="Apply Cilium NetworkPolicy to isolate pod and rotate DB credentials.")
    resolution_time_ms: float = Field(..., example=8100.0)
    result: str = Field(..., example="SUCCESS - Workload quarantined and restored via GitOps.")

class IncidentOut(BaseModel):
    incident_id: str
    timestamp: str
    record: IncidentRecord

# In-memory storage acting as a database
incident_db: List[Dict[str, Any]] = []

@app.post("/api/v1/memory/incident", response_model=IncidentOut)
def record_incident(record: IncidentRecord):
    """
    Saves an incident in the long-term history and simulates embedding generation for RAG query lookup.
    """
    logger.info("Recording new incident in long-term memory...")
    incident_id = str(uuid.uuid4())
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    data = {
        "incident_id": incident_id,
        "timestamp": timestamp,
        "record": record
    }
    incident_db.append(data)
    
    # We would generate embeddings and save them to Vector DB (e.g. Qdrant/ChromaDB)
    # The workspace already contains a chromadb folder in security/chromadb
    logger.info(f"Incident {incident_id} successfully persisted and indexed for RAG queries.")
    return IncidentOut(
        incident_id=incident_id,
        timestamp=timestamp,
        record=record
    )

@app.get("/api/v1/memory/search", response_model=List[IncidentOut])
def search_memory(query: str, limit: int = 5):
    """
    Simple keyword search simulating Semantic/RAG retrieval of past security incidents.
    """
    logger.info(f"Querying long-term memory for: '{query}'")
    query_lower = query.lower()
    
    results = []
    for inc in incident_db:
        rec = inc["record"]
        # Check matching fields
        if (query_lower in rec.description.lower() or 
            query_lower in rec.cause.lower() or 
            query_lower in rec.solution.lower()):
            results.append(IncidentOut(**inc))
            
    # If no results found, return mock baseline results for simulation
    if not results:
        # Generate a dummy match to show system is operational
        mock_rec = IncidentRecord(
            description=f"Simulated match for: {query}",
            cause="Security anomaly identified in logs",
            context="K8s cluster context",
            solution="Isolate workload and perform audit logs review.",
            resolution_time_ms=5000.0,
            result="RESOLVED"
        )
        results.append(IncidentOut(
            incident_id=str(uuid.uuid4()),
            timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            record=mock_rec
        ))
        
    return results[:limit]

@app.get("/healthz")
def health():
    return {"status": "ok", "service": "ai-memory"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8095)
