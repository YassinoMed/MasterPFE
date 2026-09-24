"""Tests unitaires pour les parsers SECAI."""
import json
import tempfile
from pathlib import Path

import pytest

from secai.api.schemas import Source, Severity
from secai.integrations.semgrep import parse_semgrep
from secai.integrations.trivy import parse_trivy
from secai.integrations.falco import parse_falco_text
from secai.integrations.kyverno import parse_kyverno
from secai.integrations.sonarqube import parse_sonarqube


def _tmp(path_ext: str, content: str) -> Path:
    p = Path(tempfile.mktemp(suffix=path_ext))
    p.write_text(content)
    return p


class TestSemgrepParser:
    def test_basic(self):
        raw = json.dumps({"results": [{"check_id": "python.eval",
                                       "path": "app.py",
                                       "start": {"line": 10},
                                       "extra": {"severity": "ERROR", "message": "eval is dangerous"}}]} )
        f = parse_semgrep(_tmp(".json", raw))
        assert len(f) == 1
        assert f[0].source == Source.semgrep
        assert f[0].severity == Severity.HIGH
        assert f[0].category == "injection"
        assert f[0].requires_human_review is True

    def test_null_safe(self):
        f = parse_semgrep(_tmp(".json", '{"results": []}'))
        assert f == []

    def test_bad_json(self):
        f = parse_semgrep(_tmp(".json", "{invalid"))
        assert f == []


class TestTrivyParser:
    def test_basic(self):
        raw = json.dumps({
            "Results": [{
                "Target": "image:1",
                "Vulnerabilities": [{
                    "PkgName": "zlib",
                    "InstalledVersion": "1.2.3",
                    "FixedVersion": "1.2.4",
                    "Severity": "CRITICAL",
                    "VulnerabilityID": "CVE-2025-0001",
                }],
            }]
        })
        f = parse_trivy(_tmp(".json", raw), image_name="securerag-hub-portal-web")
        assert len(f) == 1
        assert f[0].source == Source.trivy
        assert f[0].severity == Severity.CRITICAL
        assert f[0].raw["cve"] == "CVE-2025-0001"

    def test_empty(self):
        f = parse_trivy(_tmp(".json", '{"Results": []}'), image_name="img")
        assert f == []


class TestFalcoParser:
    def test_plaintext(self):
        f = parse_falco_text(_tmp(".log",
                                  "priority=Critical a shell was spawned in pod securerag-hub pod pod-123 ns=securerag-hub"))
        assert len(f) == 1
        assert f[0].severity == Severity.CRITICAL
        assert f[0].raw["namespace"] == "securerag-hub"

    def test_no_match(self):
        f = parse_falco_text(_tmp(".log", "this line is not falco"))
        assert f == []


class TestKyvernoParser:
    def test_basic(self):
        raw = json.dumps({
            "policyReport": [{
                "results": [{
                    "policy": "securerag-require-workload-controls",
                    "severity": "HIGH",
                    "resource": {"name": "portal-web"},
                    "message": "admission denied",
                }]
            }]
        })
        f = parse_kyverno(_tmp(".json", raw))
        assert len(f) == 1
        assert f[0].source == Source.kyverno
        assert f[0].severity == Severity.HIGH


class TestSemgrepCategorization:
    def test_secret_rule(self):
        raw = json.dumps({"results": [{"check_id": "security.semgrep.aws.accesskey",
                                        "path": "x", "start": {"line": 1},
                                        "extra": {"severity": "WARNING", "message": "AWS key"}}]} )
        f = parse_semgrep(_tmp(".json", raw))
        assert f[0].category == "secrets"
