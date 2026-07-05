import os
import httpx
import logging
from app.schemas import SecurityEventInput, AIModelResponse

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-routing-models")

INFERENCE_SERVICE_URL = os.getenv("INFERENCE_SERVICE_URL", "http://10.15.10.119:8000")

async def query_remote_model(event: SecurityEventInput, agent_name: str, model_id: str) -> AIModelResponse:
    """
    Queries the remote GPU inference server (port 8000) using the real REST API:
    Endpoint: POST /api/predict
    Payload: {"model": model_id, "prompt": prompt, "max_new_tokens": 150}
    Falls back to heuristics if the service is unreachable or errors out.
    """
    prompt = (
        f"You are the security agent '{agent_name}'. Evaluate the threat level for this event. "
        f"Event details:\nSource: {event.source}\nSeverity: {event.severity}\nLog: {event.raw_log}\n"
        f"Return verdict (BLOCK or ACCEPT), risk score (0 to 100) and brief explanation."
    )
    
    payload = {
        "model": model_id,
        "prompt": prompt,
        "max_new_tokens": 150
    }
    
    try:
        url = f"{INFERENCE_SERVICE_URL}/api/predict"
        logger.info(f"Sending real inference request to remote GPU server: {url} (Model: {model_id})")
        
        # 12 seconds timeout to handle remote inference queueing
        async with httpx.AsyncClient(timeout=12.0) as client:
            resp = await client.post(url, json=payload)
            if resp.status_code == 200:
                data = resp.json()
                
                # Extract values from API response structure
                verdict = data.get("verdict", "ACCEPT").upper()
                threat_score = float(data.get("threat_score", 15.0))
                
                # Check for LLM generation response or classifier response
                explanation = data.get("prediction", data.get("explanation", ""))
                if not explanation and "probabilities" in data:
                    explanation = f"Classifier probabilities: {data.get('probabilities')}"
                if not explanation:
                    explanation = f"Remote analysis completed with risk score {threat_score}%."
                    
                classification = "attack" if verdict == "BLOCK" or threat_score >= 50.0 else "benign"
                
                return AIModelResponse(
                    risk_score=round(threat_score / 100.0, 4),
                    classification=classification,
                    explanation=f"[{agent_name}] {explanation}",
                    confidence=0.90
                )
            else:
                logger.warning(f"Remote server returned {resp.status_code} for model {model_id}.")
    except Exception as e:
        logger.warning(f"Failed to query remote server for {model_id}: {e}. Activating fail-safe heuristics.")

    # --- Heuristic Fallback (Fail-safe) ---
    log_lower = event.raw_log.lower()
    if any(x in log_lower for x in ["/bin/sh", "/bin/bash", "nc -e", "reverse", "bash -i"]):
        return AIModelResponse(
            risk_score=0.95,
            classification="attack",
            explanation=f"[{agent_name} Heuristics] Interactive shell execution detected.",
            confidence=0.98
        )
    if any(x in log_lower for x in ["chmod +x", "chown root", "sys_ptrace", "cap_sys_admin", "etc/passwd", "etc/shadow"]):
        return AIModelResponse(
            risk_score=0.75,
            classification="suspicious",
            explanation=f"[{agent_name} Heuristics] Sensitive files access or binary modifications detected.",
            confidence=0.85
        )
        
    return AIModelResponse(
        risk_score=0.15,
        classification="benign",
        explanation=f"[{agent_name} Heuristics] Normal baseline operational log signature.",
        confidence=0.90
    )

# --- Active Masters in Council ---

async def infer_zysec_ai(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "ZySec-AI", "smollm2_1_7b")

async def infer_deephat(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "DeepHat-V1", "smollm2_1_7b")

async def infer_qwythos(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "Qwythos-9B", "qwen2_5_1_5b")

async def infer_threat_hunting_master(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "threat_hunting_master", "smollm2_1_7b")

async def infer_malware_master(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "malware_master", "smollm2_1_7b")

async def infer_cloud_security_master(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "cloud_security_master", "smollm2_1_7b")

async def infer_compliance_master(event: SecurityEventInput) -> AIModelResponse:
    # Use CySecBERT for compliance and policy checks
    return await query_remote_model(event, "compliance_master", "cysecbert")

async def infer_network_master(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "network_master", "smollm2_1_7b")

async def infer_iam_master(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "iam_master", "smollm2_1_7b")

async def infer_forensics_master(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "forensics_master", "smollm2_1_7b")

async def infer_business_impact_master(event: SecurityEventInput) -> AIModelResponse:
    return await query_remote_model(event, "business_impact_master", "smollm2_1_7b")
