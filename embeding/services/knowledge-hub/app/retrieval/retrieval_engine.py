"""Moteur de récupération vectorielle (top-K + reranking + formatage)."""
from __future__ import annotations

from typing import List, Optional

import structlog

from app.config import get_settings
from app.embedding.embedder import EmbeddingEngine, get_embedding_engine
from app.models import RetrievedChunk
from app.vectorstore.qdrant_manager import (
    QdrantManager,
    get_qdrant_manager,
    rbac_filter,
)

logger = structlog.get_logger(__name__)

# Approximation : ~4 caractères par token pour la majorité des modèles.
CHARS_PER_TOKEN = 4


class RetrievalEngine:
    def __init__(
        self,
        embedder: Optional[EmbeddingEngine] = None,
        qdrant: Optional[QdrantManager] = None,
    ) -> None:
        settings = get_settings()
        self.embedder = embedder or get_embedding_engine()
        self.qdrant = qdrant or get_qdrant_manager()
        self.collection = settings.documents_collection
        self.attack_collection = settings.attack_collection
        self.max_context_tokens = settings.max_context_tokens
        self.default_top_k = settings.top_k_default
        self.default_threshold = settings.score_threshold
        self.attack_threshold = settings.attack_score_threshold

    def retrieve_context(
        self,
        query: str,
        chatbot_domain: str,
        user_role: str,
        top_k: int = 5,
        score_threshold: float = 0.7,
    ) -> List[RetrievedChunk]:
        if not query.strip():
            raise ValueError("Query cannot be empty")

        query_vector = self.embedder.embed_single(query)
        flt = rbac_filter(user_role=user_role, chatbot_domain=chatbot_domain)

        hits = self.qdrant.search_similar(
            collection=self.collection,
            query_vector=query_vector,
            limit=top_k,
            filters=flt,
            score_threshold=score_threshold,
        )

        chunks = [
            RetrievedChunk(
                content=h.payload.get("content", ""),
                score=float(h.score),
                source_document=h.payload.get("source_document", "unknown"),
                chunk_index=int(h.payload.get("chunk_index", 0)),
                sensitivity_level=h.payload.get("sensitivity_level", "internal"),
                document_type=h.payload.get("document_type", "guide"),
            )
            for h in hits
        ]
        # Reranking : tri décroissant par score (déjà retourné trié par Qdrant,
        # mais on le garantit explicitement après transformation).
        chunks.sort(key=lambda c: c.score, reverse=True)

        logger.info(
            "context_retrieved",
            query_chars=len(query),
            domain=chatbot_domain,
            role=user_role,
            hits=len(chunks),
            threshold=score_threshold,
        )
        return chunks

    def format_context_for_llm(self, chunks: List[RetrievedChunk]) -> str:
        if not chunks:
            return ""
        max_chars = self.max_context_tokens * CHARS_PER_TOKEN
        out_parts: List[str] = []
        used = 0
        for i, chunk in enumerate(chunks, start=1):
            block = (
                f"[Source #{i}: {chunk.source_document} "
                f"(chunk {chunk.chunk_index}, score={chunk.score:.3f})]\n"
                f"{chunk.content}\n"
            )
            if used + len(block) > max_chars:
                logger.debug("context_truncated", at_chunk=i, used_chars=used)
                break
            out_parts.append(block)
            used += len(block)
        return "\n---\n".join(out_parts)

    # ---------- Attack-corpus similarity scoring ----------

    def similarity_score_attack(self, prompt: str) -> tuple[float, Optional[str]]:
        """Renvoie (max_score, attack_type) en interrogeant la collection attack_corpus."""
        if not prompt.strip():
            raise ValueError("Prompt cannot be empty")
        query_vector = self.embedder.embed_single(prompt)
        hits = self.qdrant.search_similar(
            collection=self.attack_collection,
            query_vector=query_vector,
            limit=1,
        )
        if not hits:
            return 0.0, None
        top = hits[0]
        return float(top.score), top.payload.get("attack_type")


_engine_singleton: RetrievalEngine | None = None


def get_retrieval_engine() -> RetrievalEngine:
    global _engine_singleton
    if _engine_singleton is None:
        _engine_singleton = RetrievalEngine()
    return _engine_singleton
