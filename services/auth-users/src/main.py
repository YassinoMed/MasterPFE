"""auth-users — FastAPI app.

Routes:
  POST /auth/register
  POST /auth/login
  GET  /auth/me
  GET  /users               (ADMIN, AUDITOR)
  PUT  /users/{id}/role     (ADMIN)
  DELETE /users/{id}        (ADMIN)
  GET  /health, /ready
"""
from __future__ import annotations

from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .db import get_session, init_db
from .models import LoginIn, RegisterIn, Role, RoleUpdateIn, TokenOut, UserORM, UserOut
from .security import JWTError, decode_token, hash_password, issue_token, verify_password

app = FastAPI(title="auth-users", version="0.1.0", docs_url="/docs", redoc_url=None)


@app.on_event("startup")
def _on_startup() -> None:
    init_db()


# ── Helpers ───────────────────────────────────────────────────
def _current_user(
    authorization: Annotated[str | None, Header()] = None,
    db: Annotated[Session, Depends(get_session)] = None,  # type: ignore[assignment]
) -> UserORM:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = decode_token(token)
    except JWTError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}") from exc

    user_id_raw = payload.get("sub")
    if user_id_raw is None:
        raise HTTPException(status_code=401, detail="Token missing sub")
    try:
        user_id = int(user_id_raw)
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=401, detail="Token sub invalid") from exc

    user = db.get(UserORM, user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user


def _require_role(*roles: Role):
    def _dep(user: Annotated[UserORM, Depends(_current_user)]) -> UserORM:
        if Role(user.role) not in roles:
            raise HTTPException(status_code=403, detail="Forbidden — insufficient role")
        return user

    return _dep


# ── Health ────────────────────────────────────────────────────
@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "auth-users"}


@app.get("/ready")
def ready(db: Annotated[Session, Depends(get_session)]) -> dict[str, str]:
    # Touch DB
    db.execute  # noqa: B018
    return {"status": "ready"}


# ── Auth ──────────────────────────────────────────────────────
@app.post("/auth/register", response_model=TokenOut, status_code=201)
def register(
    payload: RegisterIn,
    db: Annotated[Session, Depends(get_session)],
) -> TokenOut:
    user = UserORM(
        email=str(payload.email).lower(),
        password_hash=hash_password(payload.password),
        role=Role.USER.value,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Email already registered") from None
    db.refresh(user)
    token = issue_token(subject=str(user.id), role=user.role)
    return TokenOut(access_token=token, role=Role(user.role), user_id=user.id)


@app.post("/auth/login", response_model=TokenOut)
def login(
    payload: LoginIn,
    db: Annotated[Session, Depends(get_session)],
) -> TokenOut:
    user = db.query(UserORM).filter(UserORM.email == str(payload.email).lower()).first()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = issue_token(subject=str(user.id), role=user.role)
    return TokenOut(access_token=token, role=Role(user.role), user_id=user.id)


@app.get("/auth/me", response_model=UserOut)
def me(user: Annotated[UserORM, Depends(_current_user)]) -> UserOut:
    return UserOut(id=user.id, email=user.email, role=Role(user.role), created_at=user.created_at)


# ── User management (ADMIN) ───────────────────────────────────
@app.get("/users", response_model=list[UserOut])
def list_users(
    db: Annotated[Session, Depends(get_session)],
    _: Annotated[UserORM, Depends(_require_role(Role.ADMIN, Role.AUDITOR))],
) -> list[UserOut]:
    rows = db.query(UserORM).order_by(UserORM.id.asc()).all()
    return [UserOut(id=r.id, email=r.email, role=Role(r.role), created_at=r.created_at) for r in rows]


@app.put("/users/{user_id}/role", response_model=UserOut)
def update_role(
    user_id: int,
    payload: RoleUpdateIn,
    db: Annotated[Session, Depends(get_session)],
    _: Annotated[UserORM, Depends(_require_role(Role.ADMIN))],
) -> UserOut:
    target = db.get(UserORM, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    target.role = payload.role.value
    db.commit()
    db.refresh(target)
    return UserOut(id=target.id, email=target.email, role=Role(target.role), created_at=target.created_at)


@app.delete("/users/{user_id}")
def delete_user(
    user_id: int,
    db: Annotated[Session, Depends(get_session)],
    actor: Annotated[UserORM, Depends(_require_role(Role.ADMIN))],
) -> Response:
    if user_id == actor.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    target = db.get(UserORM, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(target)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
