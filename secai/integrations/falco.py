"""Parser Falco (logs pods/text lines)."""
from __future__ import annotations

import html
import json
import logging
import re
from pathlib import Path
from typing import List

from secai.api.schemas import Finding, Severity, Source

logger = logging.getLogger("secai.integrations")


def parse_falco_text(path: Path) -> List[Finding]:
    """Parse a Falco-generated text/log file."""
    out: List[Finding] = []
    if not path.exists():
        return out
    content = path.read_text(encoding="utf-8", errors="replace")
    for line in content.splitlines():
        line = line.strip()
        if not line or "priority" not in line.lower():
            continue
        try:
            f = _parse_falco_line(line)
            if f:
                out.append(f)
        except Exception as exc:
            logger.warning("secai: falco line parse failed: %s", exc)
    return out


def parse_falco_json(path: Path) -> List[Finding]:
    """Parse Falco JSON events (webhook format or custom export)."""
    out: List[Finding] = []
    if not path.exists():
        return out
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        logger.warning("secai: falco json parse failed %s: %s", path, exc)
        return out
    for event in data if isinstance(data, list) else [data]:
        out.append(_falco_from_json(event))
    return out


def _parse_falco_line(line: str) -> Finding | None:
    # Never include raw line content in the finding title — it may contain
    # prompt-injection payloads from untrusted logs. Keep it in evidence only.
    sev_match = re.search(r"priority=(\w+)", line, re.IGNORECASE)
    sev = sev_match.group(1).upper() if sev_match else "MEDIUM"
    if sev not in {"CRITICAL", "HIGH", "LOW", "MEDIUM"}:
        sev = "MEDIUM"
    pod_match = re.search(r"pod[/\s=;:]+([a-z0-9-]+)", line)
    pod = pod_match.group(1) if pod_match else None
    ns_match = re.search(r"namespaces?[/\s=:;]+([a-z0-9-]+)", line, re.IGNORECASE)
    if ns_match is None:
        ns_match = re.search(r"ns[/\s=:;]+([a-z0-9-]+)", line, re.IGNORECASE)
    namespace = ns_match.group(1) if ns_match else "unknown"

    safe_excerpt = html.escape(line[:200], quote=True)

    return Finding(
        source=Source.falco,
        severity=Severity(sev),
        category="runtime-intrusion",
        title="Falco runtime detection event",
        description=safe_excerpt,
        evidence=[safe_excerpt],
        raw={"namespace": namespace, "pod": pod, "_raw_truncated": safe_excerpt},
        requires_human_review=True,
    )


def _falco_from_json(evt: dict) -> Finding:
    sev = (evt.get("priority") or evt.get("severity") or "MEDIUM").upper()
    if sev not in {"CRITICAL", "HIGH", "LOW", "MEDIUM"}:
        sev = "MEDIUM"
    return Finding(
        source=Source.falco,
        severity=Severity[sev],
        category="runtime-intrusion",
        title=evt.get("description") or "Falco event",
        description=evt.get("output") or "",
        evidence=[f"rule={evt.get('rule','?')}", f"time={evt.get('time','?')}"],
        raw={"namespace": evt.get("namespace"), "pod": evt.get("pod")},
        requires_human_review=True,
    )
