"""Settings — env-driven, no secret defaults baked in."""
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AUTH_", extra="ignore")

    service_name: str = "auth-users"
    port: int = 8080
    # SQLite by default for tests/dev; Postgres URL injected in compose/k8s.
    database_url: str = "sqlite:///./auth_users.db"
    jwt_secret: str = Field(default="change-me-in-prod", min_length=8)
    jwt_algorithm: str = "HS256"
    jwt_ttl_seconds: int = 3600
    bcrypt_rounds: int = 12


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
