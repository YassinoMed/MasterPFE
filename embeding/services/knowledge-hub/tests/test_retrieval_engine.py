"""Tests du moteur de récupération."""
from __future__ import annotations

import pytest

from app.retrieval.retrieval_engine import RetrievalEngine


@pytest.fixture
def populated_engine(fake_embedder, fake_qdrant):
    engine = RetrievalEngine(embedder=fake_embedder, qdrant=fake_qdrant)
    fake_qdrant.create_collection(engine.collection, vector_size=fake_embedder.expected_dimension)
    fake_qdrant.create_collection(engine.attack_collection, vector_size=fake_embedder.expected_dimension)

    payloads = [
        {
            "content": "politique de congés payés et RTT",
            "chatbot_domain": "hr",
            "allowed_roles": ["employee", "hr_manager"],
            "sensitivity_level": "internal",
            "document_type": "policy",
            "source_document": "politique_conges.txt",
            "chunk_index": 0,
            "total_chunks": 1,
        },
        {
            "content": "procédure d'incident IT critique P1",
            "chatbot_domain": "it_support",
            "allowed_roles": ["it_admin"],
            "sensitivity_level": "confidential",
            "document_type": "procedure",
            "source_document": "procedure_incident.txt",
            "chunk_index": 0,
            "total_chunks": 1,
        },
        {
            "content": "guide reset mot de passe libre service",
            "chatbot_domain": "it_support",
            "allowed_roles": ["employee", "it_admin"],
            "sensitivity_level": "internal",
            "document_type": "guide",
            "source_document": "guide_reinitialisation_mdp.txt",
            "chunk_index": 0,
            "total_chunks": 1,
        },
    ]
    vectors = fake_embedder.embed_batch([p["content"] for p in payloads])
    fake_qdrant.upsert_vectors(engine.collection, vectors, payloads)
    return engine


def test_retrieve_context_returns_relevant_chunks(populated_engine):
    chunks = populated_engine.retrieve_context(
        query="politique de congés payés",
        chatbot_domain="hr",
        user_role="employee",
        top_k=5,
        score_threshold=0.0,
    )
    assert len(chunks) >= 1
    assert chunks[0].source_document == "politique_conges.txt"


def test_rbac_filtering_in_retrieval(populated_engine):
    # employee ne doit PAS voir la procédure incident (allowed_roles=it_admin uniquement).
    chunks = populated_engine.retrieve_context(
        query="incident critique P1",
        chatbot_domain="it_support",
        user_role="employee",
        top_k=5,
        score_threshold=0.0,
    )
    sources = {c.source_document for c in chunks}
    assert "procedure_incident.txt" not in sources


def test_rbac_filtering_blocks_cross_domain(populated_engine):
    # Une recherche RH ne doit jamais retourner un doc it_support.
    chunks = populated_engine.retrieve_context(
        query="incident",
        chatbot_domain="hr",
        user_role="employee",
        top_k=5,
        score_threshold=0.0,
    )
    for c in chunks:
        assert "procedure_incident" not in c.source_document
        assert "guide_reinitialisation" not in c.source_document


def test_score_threshold_filtering(populated_engine):
    # Threshold très élevé → aucun résultat.
    chunks = populated_engine.retrieve_context(
        query="completely unrelated query about astronomy",
        chatbot_domain="hr",
        user_role="employee",
        top_k=5,
        score_threshold=0.99,
    )
    assert chunks == []


def test_context_formatting(populated_engine):
    chunks = populated_engine.retrieve_context(
        query="politique de congés",
        chatbot_domain="hr",
        user_role="employee",
        top_k=3,
        score_threshold=0.0,
    )
    formatted = populated_engine.format_context_for_llm(chunks)
    assert "Source #1" in formatted
    assert chunks[0].source_document in formatted
    # max_context_tokens borné par max_chars
    assert len(formatted) <= populated_engine.max_context_tokens * 4 + 50


def test_format_context_empty(populated_engine):
    assert populated_engine.format_context_for_llm([]) == ""


def test_empty_query_raises(populated_engine):
    with pytest.raises(ValueError):
        populated_engine.retrieve_context(
            query="   ",
            chatbot_domain="hr",
            user_role="employee",
        )
