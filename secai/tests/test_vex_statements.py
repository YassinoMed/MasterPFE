"""Tests VEX (OpenVEX) — declarations d'exploitabilite des vulnerabilites."""
from __future__ import annotations

import json
import pytest

from secai.guardrails.vex_statements import (
    VEX_JUSTIFICATIONS,
    VEX_STATUSES,
    add_statement,
    create_vex_document,
    generate_secai_vex,
    to_openvex_json,
    vex_gate,
)


class TestVexDocument:
    def test_creation_document(self):
        doc = create_vex_document()
        assert doc.id.startswith("https://openvex.dev/")
        assert doc.author == "SecureRAG Hub Security Team"
        assert len(doc.statements) == 0

    def test_ajout_statement(self):
        doc = create_vex_document()
        add_statement(doc, "CVE-2023-49103", "not_affected",
                      "vulnerable_code_not_in_execute_path", "Test")
        assert len(doc.statements) == 1
        assert doc.statements[0].vulnerability == "CVE-2023-49103"
        assert doc.version == 2

    def test_statut_invalle_rejete(self):
        doc = create_vex_document()
        with pytest.raises(ValueError):
            add_statement(doc, "CVE-1", "invalid_status", "component_not_present", "Test")

    def test_justification_invalide_rejetee(self):
        doc = create_vex_document()
        with pytest.raises(ValueError):
            add_statement(doc, "CVE-1", "not_affected", "invalid_justification", "Test")


class TestVexJson:
    def test_format_openvex(self):
        doc = generate_secai_vex()
        raw = to_openvex_json(doc)
        d = json.loads(raw)
        assert d["@context"] == "https://openvex.dev/ns"
        assert len(d["statements"]) == 2

    def test_statement_contient_vulnerability_et_status(self):
        doc = generate_secai_vex()
        raw = to_openvex_json(doc)
        d = json.loads(raw)
        s = d["statements"][0]
        assert "vulnerability" in s
        assert s["vulnerability"]["name"] == "CVE-2023-49103"
        assert s["status"] == "not_affected"
        assert s["justification"] == "vulnerable_code_not_in_execute_path"


class TestVexGate:
    def test_cve_avec_vex_not_affected_passe(self):
        doc = generate_secai_vex()
        findings = [{"VulnerabilityID": "CVE-2023-49103", "Severity": "CRITICAL"}]
        result = vex_gate(findings, doc)
        assert result["vex_gate"]["result"] == "PASS"
        assert len(result["vex_gate"]["justified"]) == 1

    def test_cve_sans_vex_bloque(self):
        doc = generate_secai_vex()
        findings = [{"VulnerabilityID": "CVE-9999-99999", "Severity": "CRITICAL"}]
        result = vex_gate(findings, doc)
        assert result["vex_gate"]["result"] == "FAIL"
        assert result["requires_manual_review"] is True

    def test_cve_affected_bloque(self):
        doc = create_vex_document()
        add_statement(doc, "CVE-1111-22222", "affected",
                      "vulnerable_code_not_in_execute_path", "Confirmed exploitable")
        findings = [{"VulnerabilityID": "CVE-1111-22222", "Severity": "CRITICAL"}]
        result = vex_gate(findings, doc)
        assert result["vex_gate"]["result"] == "FAIL"
        assert len(result["vex_gate"]["blocking"]) == 1

    def test_severity_non_critical_ignoree(self):
        doc = generate_secai_vex()
        findings = [{"VulnerabilityID": "CVE-2023-49103", "Severity": "HIGH"}]
        result = vex_gate(findings, doc)
        assert result["vex_gate"]["total_critical"] == 0

    def test_melange_justifie_et_bloquant(self):
        doc = generate_secai_vex()
        findings = [
            {"VulnerabilityID": "CVE-2023-49103", "Severity": "CRITICAL"},  # VEX not_affected
            {"VulnerabilityID": "CVE-8888-77777", "Severity": "CRITICAL"},  # pas de VEX
        ]
        result = vex_gate(findings, doc)
        assert result["vex_gate"]["result"] == "FAIL"
        assert len(result["vex_gate"]["justified"]) == 1
        assert len(result["vex_gate"]["unknown"]) == 1
