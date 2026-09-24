"""Tests limites/seuils (PAS convenable) pour le mur SE."""
import pytest
from secai.api.schemas import Decision, Finding, Severity, Source
from secai.policies.decision_policy import DecisionPolicy


def test_critical_is_always_block():
    p = DecisionPolicy()
    assert p.decide([Finding(source=Source.trivy, severity=Severity.CRITICAL)]) == Decision.BLOCK


def test_high_is_review_if_low_confidence():
    p = DecisionPolicy()
    f = Finding(source=Source.trivy, severity=Severity.HIGH, confidence=0.2)
    assert p.decide([f]) == Decision.REVIEW


def test_medium_is_pass_if_high_confidence():
    p = DecisionPolicy()
    f = Finding(source=Source.trivy, severity=Severity.MEDIUM, confidence=0.95)
    assert p.decide([f]) == Decision.PASS


def test_inconclusive_if_no_confidence():
    p = DecisionPolicy()
    f = Finding(source=Source.falco, severity=Severity.MEDIUM, confidence=0.09)
    assert p.decide([f]) in (Decision.REVIEW, Decision.INCONCLUSIVE)


def test_block_flag_gratuit():
    """La classification doit clairement bloquer si critics multiples."""
    p = DecisionPolicy()
    findings = [Finding(source=Source.trivy, severity=Severity.CRITICAL)] * 3
    assert p.decide(findings) == Decision.BLOCK
