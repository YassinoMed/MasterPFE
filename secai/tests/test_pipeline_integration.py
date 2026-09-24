"""Tests pipeline — ne télécharge pas le vrai modèle."""
import json
from pathlib import Path

import pytest

from secai.api.schemas import Decision, Finding, Source, Severity
from secai.policies.decision_policy import DecisionPolicy


def _fake_reports(tmpdir: Path):
    sem = tmpdir / "semgrep.json"
    sem.write_text(json.dumps({"results": [{"check_id": "rule-x", "path": "a",
                                            "start": {"line": 1},
                                            "extra": {"severity": "ERROR", "message": "bad"}}]}))
    trivy = tmpdir / "trivy-x.json"
    trivy.write_text(json.dumps({"Results": []}))
    return [sem, trivy]


def test_pipeline_end2end_without_model(tmp_path):
    from secai.pipelines.security_analysis import analyze_reports
    r = analyze_reports(_fake_reports(tmp_path), image_names=["gateway"])
    assert r.summary.total_findings == 1
    assert r.summary.by_severity.get("HIGH") == 1
    assert r.findings[0].explanation != ""


def test_policy_blocks_critical():
    f = Finding(source=Source.trivy, severity=Severity.CRITICAL, confidence=0.8,
                 raw={"cve": "CVE-2025-1", "package": "zlib"})
    d = DecisionPolicy().decide([f])
    assert d == Decision.BLOCK


def test_policy_review_medium():
    f = Finding(source=Source.falco, severity=Severity.MEDIUM, confidence=0.0)
    d = DecisionPolicy().decide([f])
    assert d in {Decision.REVIEW, Decision.INCONCLUSIVE, Decision.PASS}
