"""Configuration centralisée chargée depuis les variables d'environnement."""
from functools import lru_cache
from typing import Optional

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Qdrant
    qdrant_host: str = Field(default="localhost")
    qdrant_port: int = Field(default=6333)
    qdrant_api_key: Optional[str] = Field(default=None)
    qdrant_timeout: float = Field(default=10.0)
    qdrant_retries: int = Field(default=3)

    # Embedding model
    embedding_model: str = Field(default="sentence-transformers/all-MiniLM-L6-v2")
    embedding_dimension: int = Field(default=384)
    embedding_batch_size: int = Field(default=32)

    # Chunking
    chunk_size: int = Field(default=512)
    chunk_overlap: int = Field(default=64)

    # Retrieval
    max_context_tokens: int = Field(default=2048)
    score_threshold: float = Field(default=0.7)
    attack_score_threshold: float = Field(default=0.85)
    top_k_default: int = Field(default=5)

    # Collections
    documents_collection: str = Field(default="documents")
    attack_collection: str = Field(default="attack_corpus")

    # App
    log_level: str = Field(default="INFO")
    app_host: str = Field(default="0.0.0.0")
    app_port: int = Field(default=8000)


@lru_cache
def get_settings() -> Settings:
    return Settings()
