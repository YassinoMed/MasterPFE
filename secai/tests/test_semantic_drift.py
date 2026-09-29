"""Tests du drift SÉMANTIQUE transformer (Sentence-Transformers).

Prouve que les embeddings détectent ce que le hash ne peut PAS :
  - reformulation du même concept → STABLE (hash différent, cosine élevé)
  - concept différent → SEMANTIC_DRIFT ou REPLACED
  - sortie identique → STABLE (hash ET cosine identiques)
"""
from __future__ import annotations

import pytest

from secai.guardrails.semantic_drift import check_semantic_drift, compute_semantic_similarity

# Skip tous les tests si sentence-transformers indisponible
try:
    from sentence_transformers import SentenceTransformer  # noqa
    HAS_ST = True
except ImportError:
    HAS_ST = False

pytestmark = pytest.mark.skipif(not HAS_ST, reason="sentence-transformers requis")


class TestSemanticSimilarity:
    def test_meme_concept_haute_similarite(self):
        sim = compute_semantic_similarity(
            "CVE-2023-49103 is a critical vulnerability in libcrypt package",
            "A critical security flaw was discovered in the libcrypt library",
        )
        assert sim is not None
        assert sim > 0.5

    def test_hors_sujet_faible_similarite(self):
        sim = compute_semantic_similarity(
            "CVE-2023-49103 is a critical vulnerability in libcrypt",
            "The weather today is perfect for a picnic in the park",
        )
        assert sim is not None
        assert sim < 0.3

    def test_textes_identiques_similarite_parfaite(self):
        sim = compute_semantic_similarity(
            "The same exact text should match perfectly",
            "The same exact text should match perfectly",
        )
        assert sim is not None
        assert sim > 0.99


class TestSemanticDriftVerdict:
    def test_reformulation_stable(self):
        """Reformulation du même concept → STABLE (pas de drift)."""
        v = check_semantic_drift(
            "The report identifies a HIGH severity vulnerability CVE-2023-49103 in libcrypt.",
            "A HIGH severity security flaw CVE-2023-49103 was found in the libcrypt package.",
        )
        assert v is not None
        assert v.verdict == "STABLE"
        assert v.cosine_similarity > 0.85

    def test_hors_sujet_replaced(self):
        """Sortie complètement différente → REPLACED (modèle substitué)."""
        v = check_semantic_drift(
            "The vulnerability CVE-2023-49103 in libcrypt requires immediate patching.",
            "Bonjour! Comment puis-je vous aider aujourd'hui avec votre recette de cuisine?",
        )
        assert v is not None
        assert v.verdict in ("REPLACED", "SEMANTIC_DRIFT")
        assert v.cosine_similarity < 0.5

    def test_concept_tangentiel_drift(self):
        """Concept partiellement différent → SEMANTIC_DRIFT."""
        v = check_semantic_drift(
            "Critical vulnerability in the authentication system requires patching.",
            "The authentication mechanism has been updated with new security features.",
        )
        assert v is not None
        # Le verdict doit être détecté (pas STABLE, mais peut être DRIFT ou REPLACED)
        assert v.verdict != "STABLE"

    def test_identique_stable(self):
        """Sortie strictement identique → STABLE."""
        v = check_semantic_drift(
            "ACK-SECURI-001",
            "ACK-SECURI-001",
        )
        assert v is not None
        assert v.verdict == "STABLE"
        assert v.cosine_similarity > 0.95


class TestDegradation:
    def test_sortie_complete(self):
        """Le verdict contient toutes les informations nécessaires."""
        v = check_semantic_drift(
            "Baseline output for testing",
            "Current output for testing",
        )
        assert v is not None
        assert hasattr(v, "cosine_similarity")
        assert hasattr(v, "verdict")
        assert hasattr(v, "baseline_snippet")
        assert hasattr(v, "current_snippet")
        assert 0.0 <= v.cosine_similarity <= 1.0
