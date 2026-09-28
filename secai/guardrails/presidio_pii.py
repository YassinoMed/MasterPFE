"""Guardrail PII AVANCÉ — Presidio NER multi-langues (OWASP LLM02).

Remplace le regex GO-05 basique par Presidio Analyzer :
  - 50+ types d'entités (NIF, IBAN, SSN, téléphone, adresse, IP, email,
    carte de crédit, passeport, numéro de sécurité sociale…)
  - Modèle spacy multi-langues (fr+en) avec fallback regex
  - Score de confiance par entité (seuil configurable)

Ce module complète (ne remplace pas) scan_output : Presidio pour la
détection PII profonde, le regex pour les secrets cryptographiques.

Dégradation gracieuse : si spacy n'a pas de modèle, fallback sur les
regex natives de Presidio (PatternRecognizer).
"""
from __future__ import annotations

import os
from dataclasses import dataclass

# Seuil de confiance Presidio : en dessous = bruit, au-dessus = PII réelle
PII_THRESHOLD = float(os.getenv("PII_CONFIDENCE_THRESHOLD", "0.4"))
PII_LANG = os.getenv("PII_LANG", "en")


@dataclass(frozen=True)
class PIIEntity:
    """Une entité PII détectée par Presidio."""

    entity_type: str   # EMAIL_ADDRESS, FR_NIF, PHONE_NUMBER…
    value: str         # valeur MASQUÉE (jamais l'original en clair)
    score: float       # confiance 0.0-1.0
    start: int
    end: int


# ── Engine lazy-init (le modèle spacy est lourd, pas au démarrage) ──
_engine = None


def _get_engine():
    global _engine
    if _engine is None:
        try:
            from presidio_analyzer import AnalyzerEngine

            _engine = AnalyzerEngine()
            # Support FR si le modèle spacy fr est installé
            try:
                import spacy

                if "fr_core_news_sm" in spacy.util.get_installed_models():
                    from presidio_analyzer.nlp_engine import (
                        NlpEngineProvider,
                    )

                    _engine = AnalyzerEngine(
                        nlp_engine=NlpEngineProvider(
                            nlp_configuration={
                                "nlp_engine_name": "spacy",
                                "models": [
                                    {"lang_code": "fr", "model_name": "fr_core_news_sm"},
                                    {"lang_code": "en", "model_name": "en_core_web_sm"},
                                ],
                            }
                        ).create_engine()
                    )
            except (ImportError, AttributeError):
                pass  # modèle fr absent → Presidio utilise ses regex internes
        except ImportError:
            _engine = False  # Présidio indisponible → fallback regex
    return _engine


def scan_pii_presidio(text: str, mask: str = "[PII-{}]") -> tuple[str, list[PIIEntity]]:
    """Scan PII approfondi avec Presidio. Retourne (texte_masqué, entités).

    Le texte retourné a TOUTES les PII remplacées par [PII-TYPE].
    Les entités détectées sont listées avec leur score (traçabilité).
    La valeur originale n'est JAMAIS stockée dans le résultat.
    """
    engine = _get_engine()
    if engine is False:
        # Fallback : Presidio indisponible → regex basique (GO-05)
        from secai.guardrails.output_filter import scan_output, Verdict
        v = scan_output(text)
        return v.cleaned, []

    if not text or not text.strip():
        return text, []

    results = engine.analyze(
        text=text,
        language=PII_LANG,
        entities=None,  # tous les types
        score_threshold=PII_THRESHOLD,
    )

    entities: list[PIIIEntity] = []
    # Trier par position décroissante pour masquer sans casser les offsets
    for r in sorted(results, key=lambda x: x.start, reverse=True):
        ent = PIIEntity(
            entity_type=r.entity_type,
            value=f"{r.entity_type}({r.score:.2f})",  # type+score, JAMAIS la valeur
            score=r.score,
            start=r.start,
            end=r.end,
        )
        entities.append(ent)
        text = text[: r.start] + mask.format(r.entity_type) + text[r.end :]

    return text, list(reversed(entities))


# ── Types d'entités Prioritaires pour la soutenance (le "wow" facteur) ──
# Presidio détecte nativement (extrait, 50+ au total) :
CRITICAL_ENTITIES = {
    "EMAIL_ADDRESS", "PHONE_NUMBER", "IBAN_CODE", "CREDIT_CARD",
    "FR_NIF", "FR_PASSPORT", "US_SSN", "IP_ADDRESS", "URL",
    "MEDICAL_LICENSE", "PERSON", "LOCATION", "ORGANIZATION",
    "CRYPTO", "DATE_TIME", "NRP", "US_DRIVER_LICENSE",
    "UK_NHS", "SG_NRIC_FIN", "AU_ABN", "IN_PAN",
}
