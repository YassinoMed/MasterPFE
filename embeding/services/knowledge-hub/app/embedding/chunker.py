"""Chunking récursif basé sur langchain-text-splitters."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List

import structlog
from langchain_text_splitters import RecursiveCharacterTextSplitter

from app.config import get_settings
from app.models import DocumentChunk

logger = structlog.get_logger(__name__)


class TextChunker:
    """Découpe un texte long en chunks tout en propageant les métadonnées."""

    def __init__(
        self,
        chunk_size: int | None = None,
        chunk_overlap: int | None = None,
    ) -> None:
        settings = get_settings()
        self.chunk_size = chunk_size or settings.chunk_size
        self.chunk_overlap = chunk_overlap or settings.chunk_overlap

        self._splitter = RecursiveCharacterTextSplitter(
            chunk_size=self.chunk_size,
            chunk_overlap=self.chunk_overlap,
            separators=["\n\n", "\n", ". ", " ", ""],
            length_function=len,
        )

    def split(
        self,
        text: str,
        source_document: str,
        chatbot_domain: str,
        allowed_roles: List[str],
        sensitivity_level: str,
        document_type: str,
    ) -> List[DocumentChunk]:
        if not text or not text.strip():
            logger.warning("empty_text_for_chunking", source=source_document)
            return []

        raw_chunks = self._splitter.split_text(text)
        total = len(raw_chunks)
        now = datetime.now(timezone.utc).isoformat()

        chunks: List[DocumentChunk] = []
        for idx, content in enumerate(raw_chunks):
            chunks.append(
                DocumentChunk(
                    content=content,
                    chunk_index=idx,
                    total_chunks=total,
                    source_document=source_document,
                    chatbot_domain=chatbot_domain,
                    allowed_roles=allowed_roles,
                    sensitivity_level=sensitivity_level,
                    document_type=document_type,
                    created_at=now,
                )
            )

        logger.info(
            "text_chunked",
            source=source_document,
            chunks=total,
            chunk_size=self.chunk_size,
            overlap=self.chunk_overlap,
        )
        return chunks

    def chunk_to_payload(self, chunk: DocumentChunk) -> Dict[str, Any]:
        """Convertit un chunk en payload Qdrant (toutes les métadonnées RBAC)."""
        return chunk.model_dump()
