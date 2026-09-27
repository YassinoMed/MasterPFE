"""Structures communes des guardrails — immuables et sans I/O."""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class Verdict(str, Enum):
    """Verdict binaire des guardrails — fail-closed."""

    ALLOW = "allow"
    BLOCK = "block"
    SANITIZE = "sanitize"  # autorisé après nettoyage


@dataclass(frozen=True)
class GuardrailVerdict:
    """Résultat d'un scan guardrail.

    Attributs :
        verdict      : ALLOW / BLOCK / SANITIZE
        rule         : identifiant de la règle déclenchée (ex: GI-01)
        cleaned      : texte nettoyé (identique à l'entrée si ALLOW)
        evidence     : fragments détectés (jamais interprétés — données only)
        confidence   : 0.0-1.0, jamais utilisé pour outpasser un BLOCK
    """

    verdict: Verdict
    rule: str = "none"
    cleaned: str = ""
    evidence: tuple = field(default_factory=tuple)
    confidence: float = 1.0
