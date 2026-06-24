from typing import List, Dict
from app.schemas import SecurityEventInput, AIModelResponse
from app.models import infer_zysec_ai, infer_deephat, infer_qwythos
import asyncio

async def route_event(event: SecurityEventInput) -> Dict[str, AIModelResponse]:
    """
    Core SIEM Routing Logic based on SOC2 requirements and model specialization.
    """
    tasks = {}
    results = {}

    # Rule 1: High-volume simple logs always go to ZySec
    if event.source in ["k8s", "falco", "ci-cd"]:
        tasks["ZySec-AI"] = infer_zysec_ai(event)

    # Rule 2: Network behavior or Vault access goes to DeepHat
    if event.source in ["cilium", "vault"]:
        tasks["DeepHat-V1"] = infer_deephat(event)

    # Rule 3: High severity or multi-system implies deep reasoning required
    if event.severity.upper() in ["HIGH", "CRITICAL"]:
        tasks["Qwythos-9B"] = infer_qwythos(event)
        
    # Always have at least ZySec if no other rules matched
    if not tasks:
        tasks["ZySec-AI"] = infer_zysec_ai(event)

    # Execute all selected models concurrently
    model_names = list(tasks.keys())
    responses = await asyncio.gather(*tasks.values())
    
    for name, response in zip(model_names, responses):
        results[name] = response

    return results
