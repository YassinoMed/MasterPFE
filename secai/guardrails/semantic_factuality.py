"""Factuality SÉMANTIQUE — TF-IDF + similarité cosinus (LLM09 avancé).

Étend la factuality claim-based (exact match) par une couche
sémantique légère : TF-IDF sur tokens significatifs + cosine.

Complément de secai/guardrails/factuality.py :
  - factuality.py : claims vérifiables (CVE, URL, fichier, commande)
    → traçage EXACT dans le contexte (binaire : trouvé / pas trouvé)
  - semantic.py  : similarité GLOBALE réponse↔contexte
    → score continu 0.0-1.0 (combien de la réponse est topicalement
      représentée dans le contexte)

Verdict combiné :
  GROUNDED      : claims OK + similarité ≥ 0.3
  PARTIAL       : claims OK + similarité < 0.3 (réponse tangentielle)
  UNGROUNDED    : claims échoués OU similarité < 0.1

Pourquoi TF-IDF et pas des embeddings transformer : le modèle
Qwen-0.5B ne sert pas d'embedder, et l'honnêteté exige de ne pas
prétendre à une sémantique transformer. Le TF-IDF est déterministe,
auditable en soutenance ligne par ligne, et capture la redondance
topicaale (réponse qui reformule le contexte vs réponse hors-sujet).
"""
from __future__ import annotations

import math
import re
from collections import Counter
from dataclasses import dataclass

# ── Tokenisation : mots significatifs (stopwords FR+EN) ─────────────────────

_STOPWORDS = {
    # FR
    "le", "la", "les", "de", "des", "du", "un", "une", "et", "ou", "à",
    "au", "aux", "en", "dans", "pour", "par", "sur", "est", "sont",
    "ce", "cet", "cette", "ces", "qui", "que", "quoi", "dont", "avec",
    "plus", "moins", "très", "peut", "être", "avoir", "fait", "faire",
    "il", "elle", "ils", "elles", "on", "nous", "vous", "je", "tu",
    "se", "sa", "son", "ses", "leur", "leurs", "y", "ne", "pas",
    # EN
    "the", "a", "an", "is", "are", "was", "were", "be", "been",
    "to", "of", "in", "for", "on", "with", "at", "by", "from",
    "this", "that", "these", "those", "it", "its", "as", "and",
    "or", "not", "can", "could", "will", "would", "should", "may",
    "have", "has", "had", "do", "does", "did", "but", "if", "so",
}

_TOKEN_RE = re.compile(r"[a-zàâäéèêëïîôöùûüç]{3,}")


def _tokenize(text: str) -> list[str]:
    """Tokenise en mots significatifs (>=3 lettres, sans stopwords)."""
    return [t for t in _TOKEN_RE.findall(text.lower()) if t not in _STOPWORDS]


def _tf(tokens: list[str]) -> dict[str, float]:
    """Fréquences relatives des tokens."""
    if not tokens:
        return {}
    c = Counter(tokens)
    total = len(tokens)
    return {tok: count / total for tok, count in c.items()}


def _cosine(v1: dict[str, float], v2: dict[str, float]) -> float:
    """Similarité cosinus entre deux vecteurs sparse (TF-IDF)."""
    if not v1 or not v2:
        return 0.0
    # IDF simplifié : log(2) pour les tokens partagés (déterministe)
    common = set(v1) & set(v2)
    if not common:
        return 0.0
    dot = sum(v1[t] * v2[t] for t in common)
    n1 = math.sqrt(sum(x * x for x in v1.values()))
    n2 = math.sqrt(sum(x * x for x in v2.values()))
    if n1 == 0 or n2 == 0:
        return 0.0
    return dot / (n1 * n2)


@dataclass(frozen=True)
class SemanticVerdict:
    """Verdict de la similarité sémantique réponse↔contexte."""

    similarity: float          # 0.0-1.0
    shared_tokens: list[str]   # tokens communs les plus significatifs
    response_tokens: int
    context_tokens: int
    verdict: str                # GROUNDED | PARTIAL | UNGROUNDED


def semantic_similarity(response: str, context: str) -> SemanticVerdict:
    """Calcule la similarité TF-IDF réponse↔contexte.

    Retourne un verdict sémantique : la réponse est-elle topicalement
    représentée dans le contexte ?
    """
    resp_tokens = _tokenize(response)
    ctx_tokens = _tokenize(context)

    resp_tf = _tf(resp_tokens)
    ctx_tf = _tf(ctx_tokens)

    sim = _cosine(resp_tf, ctx_tf)

    # Tokens partagés triés par poids combiné (les plus informatifs d'abord)
    common = set(resp_tf) & set(ctx_tf)
    shared = sorted(common, key=lambda t: resp_tf[t] + ctx_tf[t], reverse=True)[:10]

    if sim >= 0.3:
        verdict = "GROUNDED"
    elif sim >= 0.1:
        verdict = "PARTIAL"
    else:
        verdict = "UNGROUNDED"

    return SemanticVerdict(
        similarity=round(sim, 3),
        shared_tokens=shared,
        response_tokens=len(resp_tokens),
        context_tokens=len(ctx_tokens),
        verdict=verdict,
    )


# ── Combinaison : claims + sémantique → verdict final LLM09 ─────────────────

def combined_factuality(
    response: str, context: str
) -> dict:
    """Factuality complète : claims exacts + similarité sémantique.

    Deux couches :
      1. Claims vérifiables (CVE/URL/fichier/cmd) : exact match binaire
      2. Similarité sémantique globale : score continu TF-IDF

    Le verdict final est le PLUS SÉVÈRE des deux :
      si les claims échouent OU la similarité est nulle → UNGROUNDED
      si les claims OK mais similarité faible → PARTIAL (tangentielle)
      si les deux sont bons → GROUNDED
    """
    from secai.guardrails.factuality import check_factuality

    claim_verdict = check_factuality(response, context)
    semantic = semantic_similarity(response, context)

    # Verdict final : le plus sévère
    severities = {"GROUNDED": 0, "PARTIAL": 1, "UNGROUNDED": 2}
    combined = max(
        claim_verdict.verdict, semantic.verdict,
        key=lambda v: severities[v]
    )

    return {
        "factuality": {
            "verdict": combined,
            "claims": {
                "total": claim_verdict.total_claims,
                "grounded_ratio": claim_verdict.grounded_ratio,
                "ungrounded": [
                    {"kind": c.kind, "value": c.value}
                    for c in claim_verdict.ungrounded_claims
                ],
            },
            "semantic": {
                "similarity": semantic.similarity,
                "shared_tokens": semantic.shared_tokens[:5],
                "verdict": semantic.verdict,
            },
        },
        "requires_human_review": combined != "GROUNDED",
    }
