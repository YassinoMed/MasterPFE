import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Setup test database
TEST_DATABASE_URL = "sqlite:///./test_ai_security.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from backend.db import Base, get_db
from backend.main import app

# Override the get_db dependency
def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(autouse=True, scope="module")
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)
    if os.path.exists("./test_ai_security.db"):
        os.remove("./test_ai_security.db")

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "ai-security-backend"}


def test_analyze_and_incident_trigger():
    # Analyze a normal log
    payload = {
        "source": "Tetragon",
        "classification": "NORMAL",
        "severity": "LOW",
        "confidence": 99.0,
        "explanation": "Normal system logging",
        "recommendation": "No action needed",
        "raw_log": "system started successfully"
    }
    response = client.post("/analyze", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["classification"] == "NORMAL"
    assert data["source"] == "Tetragon"

    # Analyze a malicious log (this should trigger an incident creation)
    payload_malicious = {
        "source": "Tetragon",
        "classification": "MALICIOUS",
        "severity": "CRITICAL",
        "confidence": 98.0,
        "explanation": "Reverse shell detected",
        "recommendation": "Isolate container",
        "raw_log": "process exec /bin/sh"
    }
    response_malicious = client.post("/analyze", json=payload_malicious)
    assert response_malicious.status_code == 200
    data_malicious = response_malicious.json()
    assert data_malicious["classification"] == "MALICIOUS"

    # Fetch incidents list to verify the auto-created incident
    incidents_resp = client.get("/incidents")
    assert incidents_resp.status_code == 200
    incidents = incidents_resp.json()
    assert len(incidents) >= 1
    assert incidents[0]["source"] == "Tetragon"
    assert incidents[0]["severity"] == "CRITICAL"
    assert incidents[0]["status"] == "OPEN"
