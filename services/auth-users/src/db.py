"""Database engine + session helpers."""
from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from .config import get_settings
from .models import Base


def make_engine() -> Engine:
    settings = get_settings()
    connect_args: dict = {}
    if settings.database_url.startswith("sqlite"):
        connect_args = {"check_same_thread": False}
        return create_engine(settings.database_url, connect_args=connect_args, future=True)
    return create_engine(
        settings.database_url, 
        connect_args=connect_args, 
        pool_size=50, 
        max_overflow=100, 
        future=True
    )


_engine: Engine | None = None
_SessionLocal: sessionmaker[Session] | None = None


def init_db() -> None:
    global _engine, _SessionLocal
    if _engine is None:
        _engine = make_engine()
        Base.metadata.create_all(bind=_engine)
        _SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_engine, future=True)


def get_session() -> Generator[Session, None, None]:
    if _SessionLocal is None:
        init_db()
    assert _SessionLocal is not None
    with _SessionLocal() as session:
        yield session


def reset_for_tests() -> None:
    """Drops the whole schema; tests only."""
    global _engine, _SessionLocal
    if _engine is not None:
        Base.metadata.drop_all(bind=_engine)
        Base.metadata.create_all(bind=_engine)
