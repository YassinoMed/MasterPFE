"""Parser Trivy (vulnerabilities.json / HTML / JSON Fallback)."""
from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import List

from secai.api.schemas import Finding, Severity, Source

logger = logging.getLogger("secai.integrations")


def parse_trivy(path: Path, image_name: str) -> List[Finding]:
    """
    Parse Trivy JSON into Finding objects and group them by image.

    Does NOT downgrade: HIGH/CRITICAL is never ignored — the pipeline always
    surfaces them for human review.
    """
    out: List[Finding] = []
    if not path.exists():
        return out
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        logger.warning("secai: trivy parse failed %s: %s", path, exc)
        return out

    results = data.get("Results", [])
    if not isinstance(results, list):
        return out

    image_name_for_finding = image_name

    for result in results:
        vulns = result.get("Vulnerabilities", [])
        for v in vulns:
            pkg = v.get("PkgName", "?")
            installed = v.get("InstalledVersion", "?")
            fixed = v.get("FixedVersion", "?")
            severity_str = (v.get("Severity") or "").upper()
            severity = {"LOW": Severity.LOW, "MEDIUM": Severity.MEDIUM,
                        "HIGH": Severity.HIGH, "CRITICAL": Severity.CRITICAL}.get(
                severity_str, Severity.MEDIUM
            )
            cve = v.get("VulnerabilityID", "?")
            title = f"{cve} [{severity_str}] in {pkg}"
            desc = (v.get("Description") or title)[:200]

            out.append(
                Finding(
                    source=Source.trivy,
                    severity=severity,
                    category="vulnerability",
                    title=title,
                    description=desc,
                    evidence=[
                        f"image={image_name_for_finding}",
                        f"cve={cve}",
                        f"package={pkg}",
                        f"installed={installed}",
                        f"fixed={fixed}",
                    ],
                    raw={
                        "cve": cve,
                        "package": pkg,
                        "installed": installed,
                        "fixed": fixed,
                        "image": image_name_for_finding,
                    },
                    requires_human_review=True,
                )
            )
    return out
