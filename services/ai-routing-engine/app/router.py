import asyncio
from typing import Dict
from app.schemas import SecurityEventInput, AIModelResponse
from app.models import (
    infer_zysec_ai, infer_deephat, infer_qwythos,
    infer_threat_hunting_master, infer_malware_master,
    infer_cloud_security_master, infer_compliance_master,
    infer_network_master, infer_iam_master,
    infer_forensics_master, infer_business_impact_master
)

async def route_event(event: SecurityEventInput) -> Dict[str, AIModelResponse]:
    """
    SIEM Routing Logic routing events to specialized agents in the council.
    """
    tasks = {}
    results = {}

    # 1. Existing baseline routing (Backward Compatibility)
    if event.source in ["k8s", "falco", "ci-cd"]:
        tasks["ZySec-AI"] = infer_zysec_ai(event)
    if event.source in ["cilium", "vault"]:
        tasks["DeepHat-V1"] = infer_deephat(event)
    if event.severity.upper() in ["HIGH", "CRITICAL"]:
        tasks["Qwythos-9B"] = infer_qwythos(event)
        
    # 2. Advanced Multi-Master Council routing based on threat domain
    tasks["threat_hunting_master"] = infer_threat_hunting_master(event)
    tasks["malware_master"] = infer_malware_master(event)
    tasks["cloud_security_master"] = infer_cloud_security_master(event)
    tasks["compliance_master"] = infer_compliance_master(event)
    tasks["network_master"] = infer_network_master(event)
    tasks["iam_master"] = infer_iam_master(event)
    tasks["forensics_master"] = infer_forensics_master(event)
    tasks["business_impact_master"] = infer_business_impact_master(event)

    # Execute all selected models concurrently
    model_names = list(tasks.keys())
    responses = await asyncio.gather(*tasks.values())
    
    for name, response in zip(model_names, responses):
        results[name] = response

    return results
