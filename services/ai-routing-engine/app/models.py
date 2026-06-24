import asyncio
import random
from app.schemas import SecurityEventInput, AIModelResponse

async def infer_zysec_ai(event: SecurityEventInput) -> AIModelResponse:
    """Mock for ZySec-AI: Fast triage, usually classification."""
    await asyncio.sleep(0.1) # low latency
    # Dummy logic
    if event.severity.upper() in ["CRITICAL", "HIGH"]:
        return AIModelResponse(risk_score=0.8, classification="attack", explanation="ZySec-AI detected high severity attack signatures.", confidence=0.85)
    return AIModelResponse(risk_score=0.1, classification="benign", explanation="ZySec-AI found normal behavior.", confidence=0.95)

async def infer_deephat(event: SecurityEventInput) -> AIModelResponse:
    """Mock for DeepHat-V1-7B: Time-series anomalies."""
    await asyncio.sleep(0.5)
    # Dummy logic based on source
    if event.source in ["cilium", "vault"]:
        score = random.uniform(0.6, 0.95)
        return AIModelResponse(risk_score=score, classification="suspicious", explanation="DeepHat detected unusual temporal access patterns.", confidence=0.75)
    return AIModelResponse(risk_score=0.2, classification="benign", explanation="DeepHat baseline matching.", confidence=0.8)

async def infer_qwythos(event: SecurityEventInput) -> AIModelResponse:
    """Mock for Qwythos-9B: Deep reasoning and correlation."""
    await asyncio.sleep(1.5) # higher latency
    return AIModelResponse(
        risk_score=0.95, 
        classification="attack", 
        explanation="Qwythos-9B correlated Jenkins CI/CD anomaly with abnormal Vault access, strongly indicating a supply chain attack.", 
        confidence=0.92
    )
