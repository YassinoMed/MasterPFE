"""FastAPI application — Knowledge Hub.

Endpoints:
  POST /ingest             ingest a document into the documents collection
  POST /search             vector search with RBAC filtering
  POST /ingest-attack      ingest attack prompts into attack_corpus
  POST /similarity-score   score a prompt against the attack corpus
  GET  /collections        list collections
  GET  /health             liveness/readiness probe
"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import List

import structlog
from fastapi import FastAPI, HTTPException, status

from app import __version__
from app.config import get_settings
from app.embedding.chunker import TextChunker
from app.embedding.embedder import get_embedding_engine
from app.ingestion.document_loader import (
    DocumentReadError,
    UnsupportedFileTypeError,
    load_document,
)
from app.models import (
    CollectionInfoModel,
    CollectionsResponse,
    HealthResponse,
    IngestAttackRequest,
    IngestAttackResponse,
    IngestRequest,
    IngestResponse,
    SearchRequest,
    SearchResponse,
    SimilarityScoreRequest,
    SimilarityScoreResponse,
)
from app.retrieval.retrieval_engine import get_retrieval_engine
from app.vectorstore.qdrant_manager import get_qdrant_manager

# ---------- structlog setup ----------

settings = get_settings()

logging.basicConfig(level=settings.log_level.upper())
structlog.configure(
    processors=[
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(
        getattr(logging, settings.log_level.upper(), logging.INFO)
    ),
)
log = structlog.get_logger("knowledge-hub")


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("startup", version=__version__)
    # Pré-charge le modèle pour éviter le cold-start sur la première requête.
    get_embedding_engine()
    log.info("ready")
    yield
    log.info("shutdown")


app = FastAPI(
    title="SecureRAG Knowledge Hub",
    version=__version__,
    description="Vector knowledge hub (Qdrant + sentence-transformers) with RBAC filtering.",
    lifespan=lifespan,
)


# ---------- Endpoints ----------

@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    qdrant_ok = get_qdrant_manager().health_check()
    model_loaded = get_embedding_engine() is not None
    return HealthResponse(
        status="ok" if qdrant_ok and model_loaded else "degraded",
        qdrant=qdrant_ok,
        model_loaded=model_loaded,
    )


@app.post("/ingest", response_model=IngestResponse)
def ingest(req: IngestRequest) -> IngestResponse:
    try:
        text, meta = load_document(req.file_path)
    except FileNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail=str(exc))
    except UnsupportedFileTypeError as exc:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail=str(exc))
    except DocumentReadError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))

    chunker = TextChunker()
    chunks = chunker.split(
        text=text,
        source_document=meta["name"],
        chatbot_domain=req.chatbot_domain.value,
        allowed_roles=req.allowed_roles,
        sensitivity_level=req.sensitivity_level.value,
        document_type=req.document_type.value,
    )
    if not chunks:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, detail="No chunks produced")

    embedder = get_embedding_engine()
    vectors = embedder.embed_batch([c.content for c in chunks])
    payloads = [chunker.chunk_to_payload(c) for c in chunks]

    qdrant = get_qdrant_manager()
    if not qdrant.collection_exists(settings.documents_collection):
        qdrant.create_collection(
            settings.documents_collection,
            vector_size=embedder.expected_dimension,
            distance_metric="cosine",
        )
    qdrant.upsert_vectors(settings.documents_collection, vectors, payloads)

    return IngestResponse(
        status="ok",
        chunks_created=len(chunks),
        collection=settings.documents_collection,
        source_document=meta["name"],
    )


@app.post("/search", response_model=SearchResponse)
def search(req: SearchRequest) -> SearchResponse:
    engine = get_retrieval_engine()
    try:
        chunks = engine.retrieve_context(
            query=req.query,
            chatbot_domain=req.chatbot_domain.value,
            user_role=req.user_role,
            top_k=req.top_k,
            score_threshold=req.score_threshold,
        )
    except ValueError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(exc))

    return SearchResponse(
        results=chunks,
        total=len(chunks),
        formatted_context=engine.format_context_for_llm(chunks),
    )


@app.post("/ingest-attack", response_model=IngestAttackResponse)
def ingest_attack(req: IngestAttackRequest) -> IngestAttackResponse:
    embedder = get_embedding_engine()
    qdrant = get_qdrant_manager()

    if not qdrant.collection_exists(settings.attack_collection):
        qdrant.create_collection(
            settings.attack_collection,
            vector_size=embedder.expected_dimension,
            distance_metric="cosine",
        )

    texts = [p.example_prompt for p in req.prompts]
    vectors = embedder.embed_batch(texts)
    payloads = [
        {
            "attack_type": p.attack_type.value,
            "severity": p.severity.value,
            "description": p.description,
            "example_prompt": p.example_prompt,
        }
        for p in req.prompts
    ]
    qdrant.upsert_vectors(settings.attack_collection, vectors, payloads)
    return IngestAttackResponse(status="ok", vectors_added=len(vectors))


@app.post("/similarity-score", response_model=SimilarityScoreResponse)
def similarity_score(req: SimilarityScoreRequest) -> SimilarityScoreResponse:
    engine = get_retrieval_engine()
    try:
        score, attack_type = engine.similarity_score_attack(req.prompt)
    except ValueError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(exc))

    return SimilarityScoreResponse(
        max_score=score,
        attack_type=attack_type,
        is_suspicious=score >= settings.attack_score_threshold,
    )


@app.get("/collections", response_model=CollectionsResponse)
def list_collections() -> CollectionsResponse:
    qdrant = get_qdrant_manager()
    infos: List[CollectionInfoModel] = [
        CollectionInfoModel(**info) for info in qdrant.list_collections()
    ]
    return CollectionsResponse(collections=infos)
