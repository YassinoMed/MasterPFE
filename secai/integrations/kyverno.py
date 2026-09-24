"""Parser Kyverno (PolicyReports + admission results)."""
import json
import logging
from pathlib import Path
from typing import List

from secai.api.schemas import Finding, Severity, Source

logger = logging.getLogger("secai.integrations")


def parse_kyverno(path: Path) -> List[Finding]:
    out: List[Finding] = []
    if not path.exists():
        return out
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        logger.warning("secai: kyverno parse failed %s: %s", path, exc)
        return out

    for it in data.get("policyReport", []) or [data]:
        for result in it.get("results", []):
            policy = result.get("policy", "?")
            resource = result.get("resource", {}).get("name", "?")
            message = result.get("message", "")[:200]
            scored = result.get("scored") or ""
            sev_str = (result.get("severity") or "").upper()
            severity = {"CRITICAL": "HIGH", "HIGH": "HIGH", "MEDIUM": "MEDIUM", "LOW": "LOW"}.get(sev_str, "MEDIUM")

            out.append(
                Finding(
                    source=Source.kyverno,
                    severity=Severity[severity],
                    category="policy-violation",
                    title=f"Kyverno {policy} on {resource}",
                    description=message,
                    evidence=[f"policy={policy}", f"resource={resource}"],
                    raw={"policy": policy, "resource": resource, "message": message},
                    requires_human_review=True,
                )
            )
    return out
