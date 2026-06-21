"""SQLAlchemy ORM + Pydantic schemas."""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Annotated

from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import Column, DateTime, Integer, String
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class Role(str, Enum):
    USER = "USER"
    ADMIN = "ADMIN"
    AUDITOR = "AUDITOR"


class UserORM(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(16), nullable=False, default=Role.USER.value)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


# ── Schemas (Pydantic) ─────────────────────────────────────────
PasswordStr = Annotated[str, Field(min_length=8, max_length=128)]


class RegisterIn(BaseModel):
    email: EmailStr
    password: PasswordStr


class LoginIn(BaseModel):
    email: EmailStr
    password: PasswordStr


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: Role
    user_id: int


class UserOut(BaseModel):
    id: int
    email: EmailStr
    role: Role
    created_at: datetime


class RoleUpdateIn(BaseModel):
    role: Role
