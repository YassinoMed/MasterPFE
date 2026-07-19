"""
Integration Tests — Full Pipeline.

Tests the complete 4-layer pipeline using FastAPI TestClient
with mocked models for fast execution.
"""

import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
import models.prompt_injection
import models.jailbreak_detector
import models.cybersecurity_agent
import models.devops_agent


@pytest.fixture
def test_client():
    """Create a test client with mocked models."""
    # Mock all model loading before importing the app
    with patch("models.prompt_injection.PromptInjectionDetector._load_model"), \
         patch("models.jailbreak_detector.JailbreakDetector._load_model"), \
         patch("models.cybersecurity_agent.CyberSecurityAgent._load_model"), \
         patch("models.cybersecurity_agent.CyberSecurityAgent._detect_gpu"), \
         patch("models.devops_agent.DevOpsAgent._load_model"):

        from api.main import app
        with TestClient(app) as client:
            yield client


class TestHealthEndpoints:
    """Tests for health and readiness endpoints."""

    def test_health_check(self, test_client):
        """Health endpoint should return 200."""
        response = test_client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert data["service"] == "ai-security-service"
        assert "version" in data

    def test_readiness_check(self, test_client):
        """Readiness endpoint should return model status."""
        response = test_client.get("/readyz")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "models" in data

    def test_list_models(self, test_client):
        """Models endpoint should list registered models."""
        response = test_client.get("/api/v1/models")
        assert response.status_code == 200
        data = response.json()
        assert "models" in data
        assert "health" in data

    def test_model_statistics(self, test_client):
        """Stats endpoint should return inference statistics."""
        response = test_client.get("/api/v1/models/stats")
        assert response.status_code == 200

    def test_resource_usage(self, test_client):
        """Resources endpoint should return memory/CPU info."""
        response = test_client.get("/api/v1/resources")
        assert response.status_code == 200
        data = response.json()
        assert "process_rss_mb" in data

    def test_list_routes(self, test_client):
        """Routes endpoint should list routing categories."""
        response = test_client.get("/api/v1/routes")
        assert response.status_code == 200
        data = response.json()
        assert "categories" in data
        assert len(data["categories"]) >= 18


class TestPipelineEndpoint:
    """Tests for the main /api/v1/query endpoint."""

    def test_trace_id_header_propagated(self, test_client):
        """X-Trace-Id header should be propagated in response."""
        response = test_client.get(
            "/health",
            headers={"X-Trace-Id": "test-trace-123"}
        )
        assert response.headers.get("X-Trace-Id") == "test-trace-123"

    def test_trace_id_generated_if_missing(self, test_client):
        """X-Trace-Id should be generated if not provided."""
        response = test_client.get("/health")
        assert "X-Trace-Id" in response.headers
        assert len(response.headers["X-Trace-Id"]) > 0

    def test_empty_prompt_rejected(self, test_client):
        """Empty prompts should be rejected by validation."""
        response = test_client.post(
            "/api/v1/query",
            json={"prompt": "", "user": "test"}
        )
        assert response.status_code == 422  # Validation error


class TestMetricsEndpoint:
    """Tests for the Prometheus metrics endpoint."""

    def test_metrics_endpoint_exists(self, test_client):
        """Metrics endpoint should be accessible."""
        response = test_client.get("/metrics")
        assert response.status_code == 200
        # Prometheus format
        assert "prompt_injection_total" in response.text or "http_requests" in response.text
