"""Le cœur de la politique de décision.

SECAI ne contourne JAMAIS les outils déterministes :
- CRITICAL confirmé par Trivy reste CRITICAL.
- Kyverno et Cosign restent les arbitres d'admission.
- Les actions remédiation automatique sont désactivées par défaut.
"""
from __future__ import annotations

from typing import List

import yaml

from secai.api.schemas import Decision, Finding, Severity
from secai.config import get_settings


def _load_thresholds(path: str) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return yaml.safe_load(fh) or {}
    except FileNotFoundError:
        return {}


class DecisionPolicy:
    """Rules (priority-ordered):

    1. CRITICAL/HIGH déterministe conf -> BLOCK (si threshold haut)
    2. alert_confirmés supérieurs à deux sources → REVIEW
    3. incertitude (JSON invalide, règle inconnue) → INCONCLUSIVE
    4. Rien → PASS
    """

    def __init__(self, thresholds_path: str = "secai/policies/thresholds.yaml"):
        self.thresholds = _load_thresholds(thresholds_path)
        self.confidence_threshold = get_settings().CONFIDENCE_THRESHOLD
        self.policy_version = "secai-policies/v0.1"

    def decide(self, findings: List[Finding]) -> Decision:
        if not findings:
            return Decision.PASS

        severities = {f.severity for f in findings}
        confidences = {f.severity: f.confidence for f in findings if f.confidence}

        if Severity.CRITICAL in severities:
            # jamais ignoré par IA
            return Decision.BLOCK

        if Severity.HIGH in severities:
            # HIGH plutôt que review() par défaut (sauf si threshold rules override)
            if confidences.get(Severity.HIGH, 0.0) >= self.confidence_threshold:
                return Decision.BLOCK
            return Decision.REVIEW

        # If any finding is inconclusive, surface it
        if any(f.confidence < self.confidence_threshold for f in findings):
            return Decision.REVIEW

        # Deux sources ou plus avec même coupable ?
        by_source = {}
        for f in findings:
            by_source.setdefault(f.source.value, []).append(f)
        if len(by_source) >= 2 and Severity.MEDIUM in severities:
            return Decision.REVIEW

        return Decision.PASS
