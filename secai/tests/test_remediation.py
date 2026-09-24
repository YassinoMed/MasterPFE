"""Test du mode STRICT vs ADVISORY + seuils sur CAS de bord limité."""
from pathlib import Path

import pytest

from secai.pipelines.evaluation import evaluate_fixture
from secai.api.schemas import Decision, Finding, Severity, Source
from secai.policies.decision_policy import DecisionPolicy
from secai.pipelines.remediation import ProvenanceDecision


def test_fix_and_rebuild_with_known_fix():
    """Une vulnérabilité HIGH détectée avec une version fixed connue
    doit produire FIX_AND_REBUILD."""
    f = Finding(
        source=Source.trivy,
        severity=Severity.HIGH,
        raw={"fixedVersion": "2.9.0", "package": "league/commonmark"},
        requires_human_review=True,
    )
    p = ProvenanceDecision()
    d = p.decide([f])
    assert d == Decision.FIX_AND_REBUILD


def test_block_when_unknown_fix():
    """Fallback: si pas de fix connu, BLOCK et demande review."""
    f = Finding(source=Source.trivy, severity=Severity.CRITICAL)
    d = DecisionPolicy()
    assert d.decide([f]) == Decision.BLOCK


def test_no_finding_is_pass():
    assert DecisionPolicy().decide([]) == Decision.PASS


def test_inconclusive_when_confidence_low():
    f = Finding(source=Source.semgrep, severity=Severity.LOW, confidence=0.1)
    d = DecisionPolicy()
    assert d.decide([f]) == Decision.REVIEW


def test_thresholds_yaml_chargé():
    """Jamais un bloc avec seuil variable modifiable par environment."""
    from secai.config import get_settings
    assert get_settings().CONFIDENCE_THRESHOLD == 0.80  # default value


class TestFixtureScenarios:
    """Jeu de probes cits limites."""

    def test_false_positive_rate_hard_limits(self):
        """Le dataset authorise au plus 20% d'alertes FP."""
        r = evaluate_fixture(Path("secai/dataset/fixtures/annotated.json"))
        assert r["false_positive_rate"] <= 0.20

    def test_false_negative_rate_hard_limits(self):
        """Le taux de faux négatifs est captureur précieux: seuil pire case accepté = 25%."""
        r = evaluate_fixture(Path("secai/dataset/fixtures/annotated.json"))
        assert r["false_negative_rate"] <= 0.25


class TestDecisionLoop:
    def test_max_rebuilds_never_exceeded(self):
        """La croissance de rebuild est plafonnée par le rules collision avoidance."""
        from secai.pipelines.remediation import MAX_REBUILDS
        assert MAX_REBUILDS == 2

    def test_remediation_log_rewrite_rules(self):
        from secai.pipelines.remediation import ProvenanceDecision
        f = Finding(source=Source.trivy, severity=Severity.HIGH, requires_human_review=True)
        d = ProvenanceDecision()
        assert d.handle_fix(Decision.PASS, f) is False  # ne override jamais l'advisory
