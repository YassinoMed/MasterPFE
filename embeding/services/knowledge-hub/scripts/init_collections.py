"""Initialisation des collections Qdrant + ingestion des données de test.

Usage:
    python -m scripts.init_collections
    python -m scripts.init_collections --recreate
    python -m scripts.init_collections --skip-data
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import structlog

# Permet d'exécuter le script depuis la racine du service.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import get_settings  # noqa: E402
from app.embedding.chunker import TextChunker  # noqa: E402
from app.embedding.embedder import get_embedding_engine  # noqa: E402
from app.ingestion.document_loader import load_document  # noqa: E402
from app.models import AttackPrompt  # noqa: E402
from app.vectorstore.qdrant_manager import get_qdrant_manager  # noqa: E402

logger = structlog.get_logger(__name__)

DATA_ROOT = Path(__file__).resolve().parent.parent / "data"

# Domaine → liste de (filename, allowed_roles, sensitivity, document_type)
DOCUMENT_PLAN = {
    "hr": [
        ("politique_conges.txt", ["admin", "hr_manager", "employee"], "internal", "policy"),
        ("guide_onboarding.txt", ["admin", "hr_manager", "employee"], "internal", "guide"),
        ("faq_rh.txt", ["admin", "hr_manager", "employee"], "public", "faq"),
    ],
    "it_support": [
        ("guide_reinitialisation_mdp.txt", ["admin", "it_admin", "employee"], "internal", "guide"),
        ("faq_vpn.txt", ["admin", "it_admin", "employee"], "public", "faq"),
        ("procedure_incident.txt", ["admin", "it_admin"], "confidential", "procedure"),
    ],
}


def init_collections(recreate: bool) -> None:
    settings = get_settings()
    embedder = get_embedding_engine()
    qdrant = get_qdrant_manager()

    qdrant.create_collection(
        settings.documents_collection,
        vector_size=embedder.expected_dimension,
        distance_metric="cosine",
        recreate=recreate,
    )
    qdrant.create_collection(
        settings.attack_collection,
        vector_size=embedder.expected_dimension,
        distance_metric="cosine",
        recreate=recreate,
    )


def ingest_documents() -> int:
    embedder = get_embedding_engine()
    qdrant = get_qdrant_manager()
    settings = get_settings()
    chunker = TextChunker()

    total_chunks = 0
    for domain, files in DOCUMENT_PLAN.items():
        for filename, roles, sensitivity, doc_type in files:
            path = DATA_ROOT / domain / filename
            if not path.exists():
                logger.warning("missing_data_file", path=str(path))
                continue
            text, meta = load_document(str(path))
            chunks = chunker.split(
                text=text,
                source_document=meta["name"],
                chatbot_domain=domain,
                allowed_roles=roles,
                sensitivity_level=sensitivity,
                document_type=doc_type,
            )
            if not chunks:
                continue
            vectors = embedder.embed_batch([c.content for c in chunks])
            payloads = [chunker.chunk_to_payload(c) for c in chunks]
            qdrant.upsert_vectors(settings.documents_collection, vectors, payloads)
            total_chunks += len(chunks)
            logger.info("doc_ingested", domain=domain, file=filename, chunks=len(chunks))
    return total_chunks


def ingest_attack_corpus() -> int:
    embedder = get_embedding_engine()
    qdrant = get_qdrant_manager()
    settings = get_settings()

    corpus_path = DATA_ROOT / "attack_corpus.json"
    if not corpus_path.exists():
        logger.warning("missing_attack_corpus", path=str(corpus_path))
        return 0

    raw = json.loads(corpus_path.read_text(encoding="utf-8"))
    prompts = [AttackPrompt(**item) for item in raw]
    vectors = embedder.embed_batch([p.example_prompt for p in prompts])
    payloads = [
        {
            "attack_type": p.attack_type.value,
            "severity": p.severity.value,
            "description": p.description,
            "example_prompt": p.example_prompt,
        }
        for p in prompts
    ]
    qdrant.upsert_vectors(settings.attack_collection, vectors, payloads)
    logger.info("attack_corpus_ingested", count=len(prompts))
    return len(prompts)


def main() -> None:
    parser = argparse.ArgumentParser(description="Bootstrap Qdrant collections")
    parser.add_argument("--recreate", action="store_true", help="Drop & recreate collections")
    parser.add_argument("--skip-data", action="store_true", help="Skip data ingestion")
    args = parser.parse_args()

    init_collections(recreate=args.recreate)
    if args.skip_data:
        logger.info("data_ingestion_skipped")
        return
    docs = ingest_documents()
    attacks = ingest_attack_corpus()
    logger.info("init_complete", document_chunks=docs, attack_prompts=attacks)


if __name__ == "__main__":
    main()
