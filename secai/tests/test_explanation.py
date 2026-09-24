"""Tests unitaires pour l'explication XAI."""
from secai.pipelines.explanation import explain
from secai.api.schemas import Finding, Severity, Source


def test_explanation_not_empty():
    f = Finding(source=Source.trivy, severity=Severity.HIGH, title="x", raw={"cve": "CVE-2026-1"})
    txt = explain(f)
    assert isinstance(txt, str) and len(txt) > 10
    assert "CVE-2026-1" in txt


def test_explanation_no_injection():
    f = Finding(
        source=Source.trivy, severity=Severity.MEDIUM,
        raw={"cve": "<script>alert(1)</script>"},
    )
    txt = explain(f)
    assert "<script>" not in txt
    assert "&lt;script&gt;" in txt or txt.startswith("Finding")  # Échappé ou fallback

