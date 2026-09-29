"""VEX (Vulnerability Exploitability eXchange) — OpenVEX pour SecureRAG.

Standard OpenVEX : declarer si une vulnerabilite est EXPLOITABLE dans
le contexte d'un produit specifique, meme si elle est presente dans
une dependance.

Format : un document JSON qui liste pour chaque CVE :
  - status : "not_affected" / "affected" / "fixed" / "under_investigation"
  - justification : pourquoi
  - description : explication lisible

Fonctionnement avec les CVEs Trivy :
  - Trivy detecte CVE-2023-49103 dans secai
  - VEX declare : "not_affected car vulnerable_code_not_in_execute_path"
  - Le pipeline CI accepte l'image (decision informee, pas aveugle)
"""
from __future__ import annotations

import json
import time
from dataclasses import dataclass, field


VEX_STATUSES = {
    "not_affected": "La vulnerabilite n'est PAS exploitable",
    "affected": "La vulnerabilite EST exploitable",
    "fixed": "Corrigee dans cette version",
    "under_investigation": "En cours d'analyse",
}

VEX_JUSTIFICATIONS = {
    "component_not_present": "Le composant n'est pas inclus",
    "vulnerable_code_not_present": "Le code vulnirable a ete retire",
    "vulnerable_code_not_in_execute_path": "Code pas dans le chemin d'execution",
    "inline_mitigations_already_exist": "Mitigations deja en place",
}


@dataclass(frozen=True)
class VexStatement:
    vulnerability: str
    status: str
    justification: str
    description: str
    product: str


@dataclass
class VexDocument:
    id: str
    author: str
    timestamp: str
    statements: list = field(default_factory=list)
    version: int = 1


def generate_vex_id():
    import uuid
    return f"https://openvex.dev/docs/vex-uuid-{uuid.uuid4()}"


def create_vex_document(author="SecureRAG Hub Security Team"):
    return VexDocument(
        id=generate_vex_id(),
        author=author,
        timestamp=time.strftime("%Y-%m-%dT%H:%M:%SZ"),
    )


def add_statement(doc, vulnerability, status, justification, description,
                  product="pkg:docker/secai@sha256:107a7bc2"):
    if status not in VEX_STATUSES:
        raise ValueError(f"Statut invalide: {status}")
    if justification not in VEX_JUSTIFICATIONS:
        raise ValueError(f"Justification invalide: {justification}")
    stmt = VexStatement(vulnerability, status, justification, description, product)
    doc.statements.append(stmt)
    doc.version += 1
    return doc


def to_openvex_json(doc):
    statements = []
    for s in doc.statements:
        statements.append({
            "vulnerability": {"name": s.vulnerability},
            "products": [{"@id": s.product}],
            "status": s.status,
            "justification": s.justification,
            "description": s.description,
        })
    return json.dumps({
        "@context": "https://openvex.dev/ns",
        "@id": doc.id,
        "author": doc.author,
        "timestamp": doc.timestamp,
        "version": doc.version,
        "statements": statements,
    }, indent=2)


def generate_secai_vex():
    doc = create_vex_document(author="SecureRAG Hub MLSecOps Pipeline")
    add_statement(doc, "CVE-2023-49103", "not_affected",
        "vulnerable_code_not_in_execute_path",
        "glibc qsort buffer overflow - SECAI n'utilise pas qsort(). "
        "Le code est present mais jamais appele.",
        "pkg:docker/localhost:5001/secai@sha256:107a7bc2")
    add_statement(doc, "CVE-2024-25251", "not_affected",
        "vulnerable_code_not_in_execute_path",
        "libsystemd DNS resolver use-after-free - SECAI ne fait "
        "aucune resolution DNS dans son code applicatif.",
        "pkg:docker/localhost:5001/secai@sha256:107a7bc2")
    return doc


def vex_gate(trivy_findings, vex_doc):
    """Evalue les CRITICAL Trivy contre les VEX statements."""
    vex_map = {s.vulnerability: s for s in vex_doc.statements}
    blocking, justified, unknown = [], [], []

    for f in trivy_findings:
        cve = f.get("VulnerabilityID", "")
        sev = f.get("Severity", "").upper()
        if sev != "CRITICAL":
            continue
        if cve in vex_map:
            s = vex_map[cve]
            if s.status == "not_affected":
                justified.append({"cve": cve, "action": "PASSED (VEX)"})
            else:
                blocking.append({"cve": cve, "action": f"BLOCKED ({s.status})"})
        else:
            unknown.append({"cve": cve, "action": "BLOCKED (no VEX)"})

    has_block = len(blocking) > 0 or any("BLOCKED" in u["action"] for u in unknown)
    return {
        "vex_gate": {
            "total_critical": len(blocking) + len(justified) + len(unknown),
            "justified": justified,
            "blocking": blocking,
            "unknown": unknown,
            "result": "PASS" if not has_block else "FAIL",
        },
        "requires_manual_review": len(unknown) > 0,
    }
