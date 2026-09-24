"""Parser SonarQube (issues API JSON)."""
from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import List

from secai.api.schemas import Finding, Severity, Source

logger = logging.getLogger("secai.integrations")


def parse_sonarqube(path: Path, project: str = "securerag-hub") -> List[Finding]:
    out: List[Finding] = []
    if not path.exists():
        return out
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        logger.warning("secai: sonar parse failed %s: %s", path, exc)
        return out

    # Sonar accompanies /api/issues/search?id=...&componentKeys=...
    issues = data.get("issues", data.get("results", []))
    if not isinstance(issues, list):
        return out

    for i in issues:
        sev_str = (i.get("severity") or "MEDIUM").upper()
        severity = {"BLOCKER": "HIGH", "CRITICAL": "HIGH", "MAJOR": "MEDIUM",
                    "MINOR": "LOW", "INFO": "LOW"}.get(sev_str, "MEDIUM")
        out.append(
            Finding(
                source=Source.sonarqube,
                severity=Severity[severity],
                category="code-quality",
                title=f"Sonar {i.get('rule', '?')} on {i.get('path', '?')}",
                description=(i.get("message") or "")[:200],
                evidence=[f"rule={i.get('rule', '?')}", f"line={i.get('line', '?')}"],
                raw={"rule": i.get("rule"), "project": project},
                requires_human_review=True,
            )
        )
    return out
