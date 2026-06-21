"""Tests de l'embedder (utilise FakeEmbedder pour éviter le téléchargement modèle)."""
from __future__ import annotations

import math

import pytest

from tests.conftest import FakeEmbedder


def test_embed_single_returns_correct_dimension(fake_embedder: FakeEmbedder):
    vec = fake_embedder.embed_single("bonjour le monde")
    assert isinstance(vec, list)
    assert len(vec) == fake_embedder.expected_dimension


def test_embed_batch_consistency(fake_embedder: FakeEmbedder):
    texts = ["alpha", "beta gamma", "delta"]
    vectors = fake_embedder.embed_batch(texts)
    assert len(vectors) == len(texts)
    for v in vectors:
        assert len(v) == fake_embedder.expected_dimension
    # Same input -> same output (déterministe)
    assert fake_embedder.embed_single("alpha") == vectors[0]


def test_embedding_normalization(fake_embedder: FakeEmbedder):
    vec = fake_embedder.embed_single("politique de congés payés")
    norm = math.sqrt(sum(x * x for x in vec))
    assert norm == pytest.approx(1.0, abs=1e-6)


def test_empty_text_handling(fake_embedder: FakeEmbedder):
    with pytest.raises(ValueError):
        fake_embedder.embed_single("")
    with pytest.raises(ValueError):
        fake_embedder.embed_single("   ")
    with pytest.raises(ValueError):
        fake_embedder.embed_batch(["", "   "])


def test_get_model_info(fake_embedder: FakeEmbedder):
    info = fake_embedder.get_model_info()
    assert info["normalized"] is True
    assert info["dimension"] == fake_embedder.expected_dimension
