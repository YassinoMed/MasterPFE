"""Drift SÉMANTIQUE transformer — Sentence-Transformers + cosine (LLM09 avancé).

Étend le drift monitor (hash + latence) par une couche SÉMANTIQUE :
  - Encode chaque réponse avec all-MiniLM-L6-v2 (384 dims)
  - Compare les embeddings baseline vs courant (cosine similarity)
  - Détecte un drift SÉMANTIQUE même si le hash change pour des
    raisons bénignes (formatage, whitespace) ou reste identique
    pour des raisons malveillantes (même tokens, sens différent)

Verdicts :
  STABLE      : cosine > 0.85 (sémantique identique)
  SEMANTIC_DRIFT : 0.5 < cosine < 0.85 (signification changée)
  REPLACED    : cosine < 0.5 (modèle substitué ou corrompu)

Dégradation gracieuse : si sentence-transformers indisponible,
retourne le verdict du drift monitor classique (hash + latence).
"""
from __future__ import annotations

import os
from dataclasses import dataclass

# Seuils
SEMANTIC_STABLE = float(os.getenv("DRIFT_SEMANTIC_STABLE", "0.85"))
SEMANTIC_DRIFT_THRESHOLD = float(os.getenv("DRIFT_SEMANTIC_DRIFT", "0.50"))


@dataclass(frozen=True)
class SemanticDriftVerdict:
    """Verdict du drift sémantique pour un probe donné."""

    cosine_similarity: float    # 0.0-1.0
    verdict: str                # STABLE | SEMANTIC_DRIFT | REPLACED
    baseline_snippet: str       # extrait de la baseline
    current_snippet: str        # extrait de la réponse courante


def _get_model():
    """Lazy-init : le modèle est chargé une seule fois."""
    global _model
    if _model is None:
        try:
            from sentence_transformers import SentenceTransformer
            _model = SentenceTransformer("all-MiniLM-L6-v2")
        except ImportError:
            _model = False
    return _model


_model = None


def compute_semantic_similarity(text1: str, text2: str) -> float | None:
    """Similarité cosinus entre deux textes via embeddings transformer.

    Returns None si sentence-transformers indisponible.
    """
    model = _get_model()
    if model is False:
        return None

    emb = model.encode([text1, text2])
    from sentence_transformers.util import cos_sim
    return cos_sim(emb[0], emb[1]).item()


def check_semantic_drift(
    baseline_output: str,
    current_output: str,
) -> SemanticDriftVerdict | None:
    """Détecte un drift sémantique entre la baseline et la sortie courante.

    Le drift HASH détecte les changements binaires (substitution).
    Le drift SÉMANTIQUE détecte les changements de SIGNIFICATION :
      - une reformulation du même concept → STABLE (hash différent,
        cosine élevé)
      - un concept différent avec mots similaires → SEMANTIC_DRIFT
      - une sortie complètement différente → REPLACED
    """
    sim = compute_semantic_similarity(baseline_output, current_output)
    if sim is None:
        return None

    if sim >= SEMANTIC_STABLE:
        verdict = "STABLE"
    elif sim >= SEMANTIC_DRIFT_THRESHOLD:
        verdict = "SEMANTIC_DRIFT"
    else:
        verdict = "REPLACED"

    return SemanticDriftVerdict(
        cosine_similarity=round(sim, 4),
        verdict=verdict,
        baseline_snippet=baseline_output[:80],
        current_snippet=current_output[:80],
    )


# ── Intégration avec le drift monitor existant ───────────────────────────────

def enhanced_drift_check(probe_responses: list[dict]) -> dict:
    """Étend les résultats du drift monitor classique par la couche sémantique.

    Args:
        probe_responses : liste de {"prompt": str, "baseline": str, "current": str}

    Returns:
        Rapport enrichi avec verdicts hash + sémantique par probe.
    """
    results = {
        "probes": [],
        "semantic_alerts": [],
        "hash_alerts": [],
        "all_stable": True,
    }

    for p in probe_responses:
        # 1. Drift hash (substitution binaire)
        from secai.security_utils import compute_hash
        baseline_hash = compute_hash(p["baseline"])
        current_hash = compute_hash(p["current"])
        hash_stable = baseline_hash == current_hash

        # 2. Drift sémantique (signification)
        semantic = check_semantic_drift(p["baseline"], p["current"])

        probe_result = {
            "prompt": p["prompt"][:50],
            "hash_stable": hash_stable,
            "semantic": semantic.to_dict() if semantic else None,
        }

        if semantic and semantic.verdict != "STABLE":
            results["semantic_alerts"].append(probe_result)
            results["all_stable"] = False

        if not hash_stable:
            results["hash_alerts"].append(probe_result)
            if not semantic or semantic.verdict != "STABLE":
                results["all_stable"] = False

        results["probes"].append(probe_result)

    return results
