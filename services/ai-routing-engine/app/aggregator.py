from typing import Dict
from app.schemas import AIModelResponse

def aggregate_results(model_responses: Dict[str, AIModelResponse]) -> tuple[float, str, str]:
    """
    Aggregates responses from multiple models using a weighted scoring system.
    Returns: (final_risk_score, risk_level, combined_explanation)
    """
    weights = {
        "Qwythos-9B": 0.60,
        "DeepHat-V1": 0.30,
        "ZySec-AI": 0.10
    }
    
    total_weight = 0.0
    weighted_score_sum = 0.0
    explanations = []
    
    for model_name, response in model_responses.items():
        weight = weights.get(model_name, 0.1)
        total_weight += weight
        weighted_score_sum += response.risk_score * weight
        explanations.append(f"[{model_name}]: {response.explanation}")

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
