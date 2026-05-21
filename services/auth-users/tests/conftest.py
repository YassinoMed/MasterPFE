"""Pytest fixtures — isolated SQLite per test, fast."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


def _add_service_to_path() -> None:
    here = Path(__file__).resolve().parent.parent
    if str(here) not in sys.path:
        sys.path.insert(0, str(here))


_add_service_to_path()

# Force a clean SQLite-in-memory + deterministic JWT secret BEFORE importing src.
os.environ.setdefault("AUTH_DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("AUTH_JWT_SECRET", "test-secret-pls-change")
os.environ.setdefault("AUTH_BCRYPT_ROUNDS", "4")  # speed


@pytest.fixture()
def client():
    from src.config import get_settings
    from src.db import init_db, reset_for_tests
    from src.main import app

    get_settings.cache_clear()
    init_db()
    reset_for_tests()
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def admin_token(client):
    """Register a user, then forcibly promote to ADMIN via DB to bootstrap."""
    from sqlalchemy.orm import Session

    from src.db import _SessionLocal
    from src.models import Role, UserORM

    r = client.post("/auth/register", json={"email": "admin@example.com", "password": "pass1234"})
    assert r.status_code == 201, r.text
    assert _SessionLocal is not None
    sess: Session = _SessionLocal()
    try:
        u = sess.query(UserORM).filter(UserORM.email == "admin@example.com").one()
        u.role = Role.ADMIN.value
        sess.commit()
    finally:
        sess.close()
    # Re-login to get a fresh token with ADMIN role claim
    r = client.post("/auth/login", json={"email": "admin@example.com", "password": "pass1234"})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


@pytest.fixture()
def user_token(client):
    r = client.post("/auth/register", json={"email": "alice@example.com", "password": "pass1234"})
    assert r.status_code == 201, r.text
    return r.json()["access_token"]
