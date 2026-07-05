import os
import httpx
from typing import Dict
from app.schemas import AIModelResponse

TRUST_ENGINE_URL = os.getenv("TRUST_ENGINE_URL", "http://localhost:8093")

def aggregate_results(model_responses: Dict[str, AIModelResponse]) -> tuple[float, str, str]:
    """
    Aggregates responses from multiple models using a dynamically calculated trust-weighted score.
    Queries the trust-engine endpoint to get dynamic weights. Fallback to default weights on error.
    """
    # Baseline weights
    weights = {
        "Qwythos-9B": 0.25,
        "DeepHat-V1": 0.15,
        "ZySec-AI": 0.10,
        "threat_hunting_master": 0.05,
        "malware_master": 0.10,
        "cloud_security_master": 0.05,
        "compliance_master": 0.05,
        "network_master": 0.10,
        "iam_master": 0.05,
        "forensics_master": 0.05,
        "business_impact_master": 0.05
    }

    # Dynamic Weight Collection (Synchronous Request with short timeout)
    try:
        url = f"{TRUST_ENGINE_URL}/api/v1/trust/scores"
        # Using a sync Client with a strict timeout to ensure zero latency issues (fail-safe)
        with httpx.Client(timeout=0.5) as client:
            resp = client.get(url)
            if resp.status_code == 200:
                trust_data = resp.json()
                for agent_id, data in trust_data.items():
                    weights[agent_id] = data.get("consensus_weight", weights.get(agent_id, 0.05))
    except Exception as e:
        # Fallback to default weights silent log
        pass

    total_weight = 0.0
    weighted_score_sum = 0.0
    explanations = []

    for model_name, response in model_responses.items():
        weight = weights.get(model_name, 0.05)
        total_weight += weight
        weighted_score_sum += response.risk_score * weight
        explanations.append(f"[{model_name}](w={weight}): {response.explanation}")

    final_risk_score = weighted_score_sum / total_weight if total_weight > 0 else 0.0
    
    # Normalize risk level
    if final_risk_score >= 0.8:
        risk_level = "CRITICAL"
    elif final_risk_score >= 0.6:
        risk_level = "HIGH"
    elif final_risk_score >= 0.3:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"
        
    combined_explanation = " | ".join(explanations)
    return round(final_risk_score, 2), risk_level, combined_explanation
