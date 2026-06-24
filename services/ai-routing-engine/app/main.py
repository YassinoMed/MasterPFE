from fastapi import FastAPI, HTTPException
from app.schemas import SecurityEventInput, RoutingEngineResponse
from app.sanitizer import sanitize_event
from app.router import route_event
from app.aggregator import aggregate_results
import uuid

app = FastAPI(title="SecureRAG Hub - AI Security Routing Engine")

@app.post("/event", response_model=RoutingEngineResponse)
async def process_security_event(event: SecurityEventInput):
    """
    SOC2 Compliant SIEM AI Routing Endpoint.
    1. Sanitizes input
    2. Routes to models
    3. Aggregates decisions
    4. Logs read-only recommendations
    """
    # 1. Sanitization Layer
    clean_event = sanitize_event(event)
    
    # 2. Routing & Inference Layer
    model_responses = await route_event(clean_event)
    
    if not model_responses:
        raise HTTPException(status_code=500, detail="No AI models were routed to process this event.")
    
    # 3. Aggregation Layer
    final_score, risk_level, explanation = aggregate_results(model_responses)
    
    # Determine recommendation (Rule Engine)
    recommendation = "log and monitor"
    if risk_level in ["HIGH", "CRITICAL"]:
        recommendation = "investigate immediately and consider Falco Talon isolation"
        
    # 4. Format Output
    response = RoutingEngineResponse(
        event_id=str(uuid.uuid4()),
        final_risk_score=final_score,
        risk_level=risk_level,
        models_used=list(model_responses.keys()),
        explanation=explanation,
        recommended_action=recommendation
    )
    
    # In a real setup, we would log this to Loki here.
    return response

@app.get("/healthz")
async def health():
    return {"status": "ok"}
