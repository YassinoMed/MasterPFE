"""Tests for AI Security Orchestrator — Risk Engine."""
import pytest
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)


class TestRiskEngine:
    """Test suite for the Risk Engine."""

    def test_calculate_risk_low(self):
        """Test risk calculation with all-clear inputs."""
        response = client.post("/api/v1/risk/calculate", json={
            "semgrep_findings": 0, "semgrep_critical": 0,
            "trivy_critical": 0, "trivy_high": 0, "trivy_medium": 0,
            "grype_critical": 0, "grype_high": 0,
            "sbom_present": True, "cosign_verified": True,
            "slsa_provenance_valid": True, "image_digest_pinned": True,
            "falco_critical_events": 0, "falco_warning_events": 0,
            "kyverno_violations": 0, "error_rate_5xx": 0.0,
            "namespace": "securerag-hub", "service": "test",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["risk_score"] < 25
        assert data["decision"] == "PASS"
        assert data["risk_level"] == "LOW"

    def test_calculate_risk_critical(self):
        """Test risk calculation with critical issues."""
        response = client.post("/api/v1/risk/calculate", json={
            "semgrep_critical": 3, "trivy_critical": 5,
            "cosign_verified": False, "sbom_present": False,
            "falco_critical_events": 2, "kyverno_violations": 5,
            "namespace": "securerag-hub", "service": "test",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["risk_score"] >= 50
        assert data["decision"] in ("WARNING", "BLOCK")

    def test_calculate_risk_supply_chain_failure(self):
        """Test that missing supply chain attestations increase risk."""
        response = client.post("/api/v1/risk/calculate", json={
            "sbom_present": False, "cosign_verified": False,
            "slsa_provenance_valid": False, "image_digest_pinned": False,
            "namespace": "securerag-hub", "service": "test",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["breakdown"]["supply_chain"] == 100.0

    def test_production_multiplier(self):
        """Test that production flag increases risk score."""
        base = client.post("/api/v1/risk/calculate", json={
            "trivy_high": 3, "is_production": False,
            "namespace": "securerag-hub", "service": "test",
        })
        prod = client.post("/api/v1/risk/calculate", json={
            "trivy_high": 3, "is_production": True,
            "namespace": "securerag-hub", "service": "test",
        })
        assert prod.json()["risk_score"] >= base.json()["risk_score"]


class TestConsensusEngine:
    """Test suite for the Consensus Engine."""

    def test_unanimous_pass(self):
        """Test consensus with all agents voting PASS."""
        response = client.post("/api/v1/consensus/evaluate", json={
            "namespace": "securerag-hub", "service": "test",
            "votes": [
                {"agent_name": "code_reviewer", "decision": "PASS", "confidence": 90, "risk_score": 10},
                {"agent_name": "k8s_auditor", "decision": "PASS", "confidence": 85, "risk_score": 15},
                {"agent_name": "runtime_agent", "decision": "PASS", "confidence": 95, "risk_score": 5},
            ]
        })
        assert response.status_code == 200
        data = response.json()
        assert data["final_verdict"] == "PASS"
        assert data["consensus_score"] == 100.0
        assert data["quorum_reached"] is True

    def test_mixed_votes(self):
        """Test consensus with disagreeing agents."""
        response = client.post("/api/v1/consensus/evaluate", json={
            "namespace": "securerag-hub", "service": "test",
            "votes": [
                {"agent_name": "code_reviewer", "decision": "PASS", "confidence": 90, "risk_score": 10},
                {"agent_name": "k8s_auditor", "decision": "BLOCK", "confidence": 95, "risk_score": 80},
                {"agent_name": "runtime_agent", "decision": "WARNING", "confidence": 70, "risk_score": 50},
            ]
        })
        assert response.status_code == 200
        data = response.json()
        assert data["total_agents"] == 3

    def test_quorum_not_reached(self):
        """Test that quorum detection works."""
        response = client.post("/api/v1/consensus/evaluate", json={
            "namespace": "securerag-hub", "service": "test",
            "votes": [
                {"agent_name": "code_reviewer", "decision": "PASS", "confidence": 90, "risk_score": 10},
                {"agent_name": "k8s_auditor", "decision": "BLOCK", "confidence": 95, "risk_score": 80},
                {"agent_name": "runtime_agent", "decision": "WARNING", "confidence": 70, "risk_score": 50},
                {"agent_name": "threat_modeler", "decision": "BLOCK", "confidence": 85, "risk_score": 75},
            ]
        })
        assert response.status_code == 200


class TestDecisionEngine:
    """Test suite for the Decision Engine."""

    def test_pass_decision(self):
        """Test PASS decision with good scores."""
        response = client.post("/api/v1/decision/evaluate", json={
            "risk_score": 20, "consensus_score": 90,
            "consensus_verdict": "PASS", "quorum_reached": True,
            "sbom_present": True, "cosign_verified": True, "slsa_valid": True,
        })
        assert response.status_code == 200
        assert response.json()["decision"] == "PASS"

    def test_block_missing_cosign(self):
        """Test that missing Cosign triggers BLOCK."""
        response = client.post("/api/v1/decision/evaluate", json={
            "risk_score": 10, "consensus_score": 100,
            "cosign_verified": False, "sbom_present": True, "slsa_valid": True,
        })
        assert response.status_code == 200
        assert response.json()["decision"] == "BLOCK"

    def test_block_high_risk(self):
        """Test that critical risk score triggers BLOCK."""
        response = client.post("/api/v1/decision/evaluate", json={
            "risk_score": 80, "consensus_score": 60,
            "cosign_verified": True, "sbom_present": True, "slsa_valid": True,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["decision"] == "BLOCK"
        assert data["rollback_recommended"] is True

    def test_manual_override(self):
        """Test manual override functionality."""
        response = client.post("/api/v1/decision/evaluate", json={
            "risk_score": 90, "manual_override": "FORCE_PASS",
            "cosign_verified": False,
        })
        assert response.status_code == 200
        assert response.json()["decision"] == "PASS"


class TestHealthEndpoints:
    """Test health and readiness endpoints."""

    def test_healthz(self):
        response = client.get("/healthz")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"

    def test_readyz(self):
        response = client.get("/readyz")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"
