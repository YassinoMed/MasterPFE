"""Moteur d'embedding basé sur sentence-transformers avec normalisation L2."""
from __future__ import annotations

from typing import List

import numpy as np
import structlog
from sentence_transformers import SentenceTransformer

from app.config import get_settings

logger = structlog.get_logger(__name__)


class EmbeddingEngine:
    """Encapsule le modèle SentenceTransformer + batch + normalisation L2."""

    def __init__(
        self,
        model_name: str | None = None,
        batch_size: int | None = None,
    ) -> None:
        settings = get_settings()
        self.model_name = model_name or settings.embedding_model
        self.batch_size = batch_size or settings.embedding_batch_size
        self.expected_dimension = settings.embedding_dimension

        logger.info("loading_embedding_model", model=self.model_name)
        self._model = SentenceTransformer(self.model_name)
        actual_dim = self._model.get_sentence_embedding_dimension()
        if actual_dim != self.expected_dimension:
            logger.warning(
                "embedding_dimension_mismatch",
                expected=self.expected_dimension,
                actual=actual_dim,
            )
            self.expected_dimension = actual_dim
        logger.info("embedding_model_ready", dimension=self.expected_dimension)

    @staticmethod
    def _l2_normalize(vectors: np.ndarray) -> np.ndarray:
        norms = np.linalg.norm(vectors, axis=1, keepdims=True)
        norms = np.where(norms == 0, 1.0, norms)
        return vectors / norms

    def embed_single(self, text: str) -> List[float]:
        if not text or not text.strip():
            raise ValueError("Cannot embed empty text")
        vec = self._model.encode([text], convert_to_numpy=True, show_progress_bar=False)
        vec = self._l2_normalize(vec)
        return vec[0].tolist()

    def embed_batch(self, texts: List[str]) -> List[List[float]]:
        if not texts:
            return []
        cleaned = [t for t in texts if t and t.strip()]
        if not cleaned:
            raise ValueError("All input texts are empty")
        logger.debug("embedding_batch", count=len(cleaned), batch_size=self.batch_size)
        vectors = self._model.encode(
            cleaned,
            batch_size=self.batch_size,
            convert_to_numpy=True,
            show_progress_bar=False,
        )
        vectors = self._l2_normalize(vectors)
        return vectors.tolist()

    def get_model_info(self) -> dict:
        return {
            "model_name": self.model_name,
            "dimension": self.expected_dimension,
            "batch_size": self.batch_size,
            "normalized": True,
        }


_engine_singleton: EmbeddingEngine | None = None


def get_embedding_engine() -> EmbeddingEngine:
    global _engine_singleton
    if _engine_singleton is None:
        _engine_singleton = EmbeddingEngine()
    return _engine_singleton
