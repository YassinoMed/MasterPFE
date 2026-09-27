"""Guardrails LLM — défense en profondeur pour le stack IA.

Quatre couches indépendantes et testables :
- injection.py     : détection d'injections de prompt (OWASP LLM01, LLM07)
- output_filter.py : filtrage des sorties modèle — secrets, PII, commandes (LLM02, LLM05)
- rate_limit.py    : token bucket par client — anti déni de service (LLM10)
- schemas.py       : structures de résultats partagées

Principes :
- Aucune dépendance externe (stdlib uniquement) — auditable de bout en bout.
- Déterministe : mêmes entrées => mêmes verdicts (reproductibilité soutenance).
- Fail-closed : en cas de doute, on bloque (BLOCK) plutôt que laisser passer.
"""
from secai.guardrails.schemas import GuardrailVerdict, Verdict
from secai.guardrails.injection import scan_prompt_injection
from secai.guardrails.output_filter import scan_output
from secai.guardrails.rate_limit import TokenBucketLimiter

__all__ = [
    "GuardrailVerdict",
    "Verdict",
    "scan_prompt_injection",
    "scan_output",
    "TokenBucketLimiter",
]
