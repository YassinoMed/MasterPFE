"""Auth flow + RBAC tests."""
from __future__ import annotations


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["service"] == "auth-users"


def test_register_then_login(client):
    r = client.post("/auth/register", json={"email": "bob@example.com", "password": "pass1234"})
    assert r.status_code == 201, r.text
    assert r.json()["role"] == "USER"

    r2 = client.post("/auth/login", json={"email": "bob@example.com", "password": "pass1234"})
    assert r2.status_code == 200
    token = r2.json()["access_token"]
    assert token


def test_register_duplicate_email_conflict(client):
    payload = {"email": "dup@example.com", "password": "pass1234"}
    assert client.post("/auth/register", json=payload).status_code == 201
    r2 = client.post("/auth/register", json=payload)
    assert r2.status_code == 409


def test_login_wrong_password(client):
    client.post("/auth/register", json={"email": "carol@example.com", "password": "pass1234"})
    r = client.post("/auth/login", json={"email": "carol@example.com", "password": "wrongpass"})
    assert r.status_code == 401


def test_me_with_valid_token(client, user_token):
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {user_token}"})
    assert r.status_code == 200
    assert r.json()["email"] == "alice@example.com"
    assert r.json()["role"] == "USER"


def test_me_missing_token(client):
    r = client.get("/auth/me")
    assert r.status_code == 401


def test_me_invalid_token(client):
    r = client.get("/auth/me", headers={"Authorization": "Bearer not-a-jwt"})
    assert r.status_code == 401


def test_user_cannot_list_users(client, user_token):
    r = client.get("/users", headers={"Authorization": f"Bearer {user_token}"})
    assert r.status_code == 403


def test_admin_can_list_users(client, admin_token):
    r = client.get("/users", headers={"Authorization": f"Bearer {admin_token}"})
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_admin_can_change_role(client, admin_token):
    # Create a target user
    client.post("/auth/register", json={"email": "target@example.com", "password": "pass1234"})
    listed = client.get("/users", headers={"Authorization": f"Bearer {admin_token}"}).json()
    target_id = next(u["id"] for u in listed if u["email"] == "target@example.com")

    r = client.put(
        f"/users/{target_id}/role",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"role": "AUDITOR"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["role"] == "AUDITOR"


def test_admin_cannot_self_delete(client, admin_token):
    me = client.get("/auth/me", headers={"Authorization": f"Bearer {admin_token}"}).json()
    r = client.delete(f"/users/{me['id']}", headers={"Authorization": f"Bearer {admin_token}"})
    assert r.status_code == 400


def test_user_cannot_change_role(client, user_token, admin_token):
    me = client.get("/auth/me", headers={"Authorization": f"Bearer {user_token}"}).json()
    r = client.put(
        f"/users/{me['id']}/role",
        headers={"Authorization": f"Bearer {user_token}"},
        json={"role": "ADMIN"},
    )
    assert r.status_code == 403
