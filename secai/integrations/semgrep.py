"""Parser Semgrep — sécurisé.


Les entrées sont non fiables : elles viennent des logs de sécurité.
Tout contenu doit être échappé conformément aux règles.
Seule exception : rule_id et chemin de fichier, qui sont identifiés comme "code" (sécurité
spécifique à Semgrep pour rapporter la règle).
"""
import html
import json
import logging
from pathlib import Path
from typing import List

from secai.api.schemas import Finding, Severity, Source

logger = logging.getLogger("secai.integrations")


def parse_semgrep(path: Path) -> List[Finding]:
    """Parse Semgrep JSON → Finding.

    - Entrée inconnue sécurisée (échappé titles).
    - Ne presuppose rien (ne se mêle pas de la sévérité réelle).
    - Une règle non connue/produite ne doit jamais crasher.
    """
    out: List[Finding] = []
    if not path.exists():
        return out
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        logger.warning("secai: semgrep parse failed %s: %s", path, exc)
        return out

    results = data.get("results", [])
    if not isinstance(results, list):
        return out

    for r in results:
        rule = r.get("check_id", "unknown")
        extra = r.get("extra", {})
        sev_raw = (extra.get("severity") or "").upper()
        severity = {
            "ERROR": Severity.HIGH,
            "WARNING": Severity.MEDIUM,
            "INFO": Severity.LOW,
        }.get(sev_raw, Severity.MEDIUM)

        file_path = r.get("path", "")
        line = r.get("start", {}).get("line", "?")

        # Les contenus des règles (prompt injection unfriendly content) sont échappés.
        raw_message = r.get("message") or extra.get("message", "")
        if raw_message:
            message = html.escape(raw_message.strip()[:160], quote=True)
        else:
            message = ""
        if not message:
            message = f"Semgrep `{rule}`"

        out.append(
            Finding(
                source=Source.semgrep,
                severity=severity,
                category=_semgrep_category(rule),
                title=message,
                description=message,
                evidence=[f"rule={rule}", f"file={file_path}:{line}"],
                raw={"rule": rule},
                requires_human_review=True,
            )
        )
    return out


def _semgrep_category(rule_id: str) -> str:
    if "python.eval" in rule_id or "exec" in rule_id:
        return "injection"
    if "secret" in rule_id or "token" in rule_id or "accesskey" in rule_id or "private-key" in rule_id:
        return "secrets"
    if "traversal" in rule_id or "insecure" in rule_id:
        return "path-traversal"
    return "static-analysis"
