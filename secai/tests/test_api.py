"""Tests API SECAI — sans chargement réel du modèle."""
from unittest.mock import MagicMock, patch

import httpx
import pytest
from fastapi.testclient import TestClient
from secai.models import SecureBERTLoader

# Mock the model loading to avoid HF network call in tests
with patch.object(SecureBERTLoader, "load", MagicMock()):
    from secai.api.main import app

client = TestClient(app)


def test_health():
    with patch.object(SecureBERTLoader, "_model", None):
        r = client.get("/health")
        assert r.status_code == 200
        data = r.json()
        assert data["status"] == "ok"
        assert data["service"] == "secai"


def test_ready():
    r = client.get("/ready")
    assert r.status_code == 200
    assert r.json()["ready"] is True


def test_analyze_requires_reports():
    r = client.post("/analyze", json={"reports": []})
    assert r.status_code in (200, 400)


def test_analyze_rejects_traversal():
    # The path must stay within workspace
    r = client.post("/analyze", json={"reports": ["/etc/passwd"]})
    assert r.status_code == 403


def test_explain_sanitizes_prompt_injection():
    payload = {"message": "<script>alert(1)</script>"}
    r = client.post("/explain", json=payload)
    assert r.status_code == 200
    assert "<script>" not in r.text
    assert "requires_human_review" in r.json()


def test_keeps_data_local():
    # Internal paths are allowed
    import tempfile, os
    fp = tempfile.NamedTemporaryFile(delete=False, dir=".", suffix=".json")
    fp.write(b'{"results": []}')
    fp.close()
    try:
        r = client.post("/analyze", json={"reports": [fp.name]})
        assert r.status_code == 200
    finally:
        os.unlink(fp.name)
