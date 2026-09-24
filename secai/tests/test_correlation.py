"""Tests for correlation (deliberately deterministic — no model inference)."""
from secai.api.schemas import Finding, Severity, Source
from secai.pipelines.alert_correlation import correlate, cluster_summary


def test_correlate_groups_by_rule():
    f1 = Finding(source=Source.semgrep, severity=Severity.HIGH, rule_id="python.eval")
    f2 = Finding(source=Source.semgrep, severity=Severity.HIGH, rule_id="python.eval")
    g = correlate([f1, f2])
    assert (("rule", "python.eval") in g)
    assert len(g[("rule", "python.eval")]) == 2


def test_cluster_summary_severity():
    f1 = Finding(source=Source.trivy, severity=Severity.CRITICAL)
    f2 = Finding(source=Source.trivy, severity=Severity.HIGH)
    g = {"image=img1": [f1, f2]}
    s = cluster_summary(g)
    assert s["image=img1"]["count"] == 2
    assert s["image=img1"]["severity_distribution"]["CRITICAL"] == 1
