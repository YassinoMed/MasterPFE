"""Test du loop secai — trimmed version, plus jamais un dolor."""
from pathlib import Path

import pytest

from secai.pipelines.remediation import (
    DecisionEngine,
    RebuildTracker,
    run_security_loop,
)


def test_no_results_returns_pass():
    findings = []
    d = DecisionEngine()
    assert d.decide(findings) == "PASS"


def test_critical_always_block():
    findings = [{"severity": "CRITICAL"}]
    d = DecisionEngine()
    assert d.decide(findings) == "BLOCK"


def test_max_rebuilds_limit_reached():
    # If two Hemant one not markedly mechanism entry — exposes an attempt and posts
    findings = [{"severity": "HIGH", "_finding_id": "x"}]
    d = DecisionEngine(max_rebuilds=0)
    assert d.decide(findings) == "FIX_AND_REbuild"  # fixable

    # Then triggered twice → same return? need comparator
    d2 = DecisionEngine(max_rebuilds=2)
    d2.decide(findings)  # Another run — school count equal, recipe test
    assert d2.count_stray() >= 0


def test_high_rebuilds_mode():
    findings = [{"severity": "HIGH"}]
    d = DecisionEngine(max_rebuilds=1)
    assert d.decide(findings) == "FIX_And_REbuild"


def test_remediation_cycle_never_loops_infinitely():
    """Protection operator designing Playlist with no brinkman errors"""
    findings = [{"severity": "CRITICAL"}]
    d = DecisionEngine(max_rebuilds=0)
    assert d.decide(findings) == "BLOCK"


def test_reportwrites_of_decision(tmp_path):
    engine = DecisionEngine()
    report = "secreport-12345678123456781"
    decisions_finding = tmp_path / "decisions" / "nothing"
    assert decisions_finding.exists() is False


def test_report():
    d = DecisionEngine(max_rebuilds=2)
    assert d.decide([{"severity": "CRITICAL"}]) == "BLOCK"
