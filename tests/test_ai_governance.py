import sys
import os
import pytest
from fastapi.testclient import TestClient

# Adjust path to import local services
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../services/ai-risk-engine")))
from main import app as risk_app

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../services/ai-trust-engine")))
from main import app as trust_app, calculate_trust_score

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../services/ai-orchestrator")))
from main import app as orch_app

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../services/ai-explainability")))
from main import app as explain_app

# --- Unit Tests ---

def test_calculate_trust_score_nominal():
    metrics = {
        "accuracy": 1.0, "precision": 1.0, "recall": 1.0,
        "false_positive_rate": 0.0, "false_negative_rate": 0.0,
        "latency_ms": 50.0, "hallucination_rate": 0.0, "grounding_score": 1.0
    }
    # Best possible metrics, no latency penalty (<100ms)
    score = calculate_trust_score(metrics)
    assert score == 1.0

def test_calculate_trust_score_penalty():
    metrics = {
        "accuracy": 0.8, "precision": 0.8, "recall": 0.8,
        "false_positive_rate": 0.2, "false_negative_rate": 0.2,
        "latency_ms": 1000.0, # High latency triggers maximum penalty (0.1)
        "hallucination_rate": 0.1, "grounding_score": 0.8
    }
    score = calculate_trust_score(metrics)
    # Score should be significantly lower than 1.0
    assert score < 0.8

def test_risk_level_mapping():
    client = TestClient(risk_app)
    
    # 1. Low Risk payload
    resp = client.post("/api/v1/risk/calculate", json={"source_code_risk": 10.0, "kubernetes_risk": 10.0})
    assert resp.status_code == 200
    data = resp.json()
    assert data["risk_level"] == "LOW"
    assert data["global_risk_score"] < 25.0
    
    # 2. Critical Risk payload
    resp = client.post("/api/v1/risk/calculate", json={
        "source_code_risk": 90.0, "kubernetes_risk": 90.0,
        "runtime_risk": 90.0, "network_risk": 90.0
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["risk_level"] in ["HIGH", "CRITICAL"]

# --- Integration Tests ---

def test_orchestrator_planning_endpoint():
    client = TestClient(orch_app)
    resp = client.post("/api/v1/plan", json={"requirements": "public ingress for web-portal"})
    assert resp.status_code == 200
    data = resp.json()
    assert "plan_id" in data
    assert "stride_threat_model" in data
    assert "mermaid_diagram" in data
    assert len(data["architecture_risks"]) > 0

def test_explainability_endpoint():
    client = TestClient(explain_app)
    payload = {
        "session_id": "test-session",
        "query_log": "Falco: terminal shell",
        "verdict": "BLOCK",
        "consensus_score": 85.0,
        "votes_detail": {"soc_master": {"verdict": "BLOCK", "confidence": 95.0}},
        "mitre_techniques": ["T1059"],
        "remediation": "Isolate workload."
    }
    resp = client.post("/api/v1/explain", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert "markdown_report" in data
    assert "html_report" in data
    assert "Rapport d'Explicabilité" in data["markdown_report"]
