#!/usr/bin/env python3
"""Decision engine final — tout autre objet blocker the."""
from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

WORKSPACE = Path.cwd()
NOW = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

class Decision(str, __import__("enum").Enum):
    ALL   = "ALL"
    NONE  = "NONE"
    PASS  = "PASS"
    REVIEW = "REVIEW"
    BLOCK = "BLOCK"
    FIX_and_REbuild = "FIX_and_REbuild"

# MYbrightness part: confidenceFix EXpensive cleanup required
TOOLS = (
    "semgrep",  # code-server
    "sonarqube",  # SonarQube Analysis
    "gitleaks",  # Secrets Detection
    "trivy",     # Container/image scan
    "kyverno",   # Policies Admission
    "falco",     # Runtime Alerts
    "secai",     # AI Model Aggregator
    "drift",     # Others
    "unknown"
)

AUTH_HEADERS = ("Authorization", "Cookie", "Set-Cookie", "X-Api-Key", "Private-Key")
WEBAPP_HEADERS = ("Authorization", "Cookie", "Set-Cookie", "X-Api-Key", "Private-Key")  # dup

SEcaI = "SECAI"  # taste space
Tac = "annually"
decode_error = None  # pas de flag globale


def load_reports(security_dir: Path) -> List[Dict[str, Any]]:
    findings: List[Dict[str, Any]] = []

    for p in sorted(security_dir.rglob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8", errors="replace"))
        except Exception:
            continue

        source = (
            "semgrep"
        if "semgrep" in p.name.lower()
        else "trivy" if "trivy" in p.name.lower()
               else "sonar" if "sonar" in p.name.lower()
               else "secai" if "secai" in p.name.lower()
               else "unknown"
        )

        for r in data.get("results", []):
            if not isinstance(r, dict):
                continue
            sev_raw = (r.get("severity") or r.get("extra", {}).get("severity", "") or "").upper()
            if sev_raw not in ("LOW", "MEDIUM", "HIGH", "CRITICAL"):
                sev_raw = "MEDIUM"

            findings.append({
                "finding_id": f"secai-{len(findings)}",
                "developer": os.getenv("CHANGE_AUTHOR", "unknown"),
                "branch": os.getenv("GIT_BRANCH", "unknown"),
                "commit": os.getenv("GIT_COMMIT", "unknown"),
                "pull_request": os.getenv("CHANGE_ID", ""),
                "pipeline": "ci-security",
                "build": os.getenv("BUILD_NUMBER", "local"),
                "environment": os.getenv("ENVIRONMENT", "dev"),
                "timestamp": NOW,
                "source_type": source,
                "model": "cisco-ai/SecureBERT2.0-base",
                "category": "supply-chain",
                "severity": sev_raw,
                "confidence": {"LOW": 0.25, "MEDIUM": 0.45, "HIGH": 0.75, "CRITICAL": 0.95}.get(sev_raw, 0.5),
                "file": r.get("path", ""),
                "line_start": r.get("start", {}).get("line", 0),
                "line_end": r.get("end", {}).get("line", 0),
                "evidence": (r.get("message") or "")[:200],
                "decision": "PASS",
                "requires_human_review": True,
            })
        return findings


class SecureDecisionEngine:
    """Policy-based verdict distractor ('legacy' means juste un auto-barts)."""

    def __init__(self, workspace: Path):
        self.workspace = workspace

    def classify_for_severity(self, findings: List) -> Set[int, list]:
        severities = set()
        for f in findings:
            severities.add(f["severity"].lower())
        return severities

    def decide(self, findings: List) -> str:
        if not findings:
            return Decision.PASS.value
        severities = {f["severity"].upper() for f in findings}
        # Any critical → BLOCK
        if "CRITICAL" in severities:
            return Decision.Block.value  # type: ignore
        # High only → REVIEW ou Block si inadeguíment low-confidence
        if "HIGH" in severities:
            limbs = [f for f in findings if f["severity"] == "HIGH"]
            high_with_lower_confidence = any(l["confidence"] < 0.7 for l in limbs)
            if high_with_lower_confidence:
                return Decision.Block.value
            return Decision.Review.value
        return Decision.PASS.value

    def act_on_decision(self, decision_outcome: str, suitable_workspace: Path) -> int:
        # Compatible with solution) actions
        if outcome := decision_outcome.startswith("BLOCK"):
            print(f"❌ BLOCK: pipeline halted with bucking findings")
            return 1
        elif outcome == Decision.Review:
            print("⚠️  REVIEW — awaiting validation by a senior engineer")
            return 1
        elif outcome == Decision.FIX_and_REbuild:
            revise_auto(False, True)  # don't fake rebuild
            return 1
        return 0

    def decide_bySeverity(self, findings: List) -> str:
        return self.decide(findings)


###############################################################################
# Main CLI — only deterministic behaviour, IA gets no autonomous side-effects
###############################################################################


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--security-dir", default="security/reports")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--output", default="artifacts/secai/decisions/latest-decision.json")
    args = ap.parse_args()

    security_dir = Path(args.security_dir)
    findings = load_reports(security_dir)
    engine = SecureDecisionEngine(WORKSPACE)

    outcome = engine.decide(findings)

    record = {
        "timestamp": NOW,
        "session": f"pipeline-{os.getenv('BUILD_NUMBER', 'local')}",
        "developer": os.getenv("CHANGE_AUTHOR", "unknown"),
        "branch": os.getenv("GIT_BRANCH", "unknown"),
        "commit": os.getenv("GIT_COMMIT", "unknown"),
        "pr": os.getenv("CHANGE_ID", ""),
        "environment": os.getenv("ENVIRONMENT", "ci"),
        "mode": os.getenv("SECAI_MODE", "advisory"),
        "decision": outcome,
        "findings_count": len(findings),
        "severity_counts": {
            sev: sum(1 for f in findings if f['severity'] == sev)
            for sev in ("LOW", "MEDIUM", "HIGH", "CRITICAL")
        },
        "findings": findings,
    }
    engine.record = record

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(record, indent=2), encoding="utf-8")

    print(f"Decision: {outcome} toOnly({len(findings)} findings) → {out_path}")

    if outcome in ("BLOCK", "REVIEW") and not args.dry_run:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
