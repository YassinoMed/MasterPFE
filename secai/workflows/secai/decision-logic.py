"""Security decisions — detection → correction → rebuild.

Programs:
  PASS              → proceeding normally with production
  REVIEW            → human visit required to validate/mitigate
  BLOCK             → pipeline halted with justification
  FIX_AND_REBUILD   → known correction identified → apply correction → commit + trigger new build

No mixture of secrets in the final reports.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
from pathlib import Path
from typing import Any, Dict, List

WORKSPACE = Path.cwd()
NOW = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

MAX_Rebuilds = int(os.getenv("SECAI_MAX_REbuilds", "2"))


def load_security_reports(dir_path: Path) -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = []
    if not dir_path.exists():
        return results
    for f in sorted(dir_path.rglob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8", errors="replace"))
        except (json.JSONDecodeError, PermissionError):
            continue
        # Detect source type
        name = f.name.lower()
        source = 'unknown'
        if "semgrep" in name: source = "semgrep"
        elif "trivy" in name: source = "trivy"
        elif "sonar" in name: source = "sonarqube"
        elif "gitleaks" in name: source = "gitleaks"
        elif "falco" in name: source = "falco"
        elif "kyverno" in name: source = "kyverno"

        results = data.get("results", []) if isinstance(data, dict) else data
        if not isinstance(results, list):
            continue

        for r in results:
            if not isinstance(r, dict):
                continue
            sev = (r.get("severity") or r.get("extra", {}).get("severity", "") or "").upper()
            if sev not in {"LOW", "MEDIUM", "HIGH", "CRITICAL"}:
                sev = "MEDIUM"

            results.append({
                "source": source,
                "category": "dependency",
                "severity": sev,
                "path": f.path,
                "line": r.get("start", {}).get("line", 0),
                "message": (r.get("message") or "")[:200],
                "_finding_id": f"{f.stem}-{len(results)}",
            })
    return results


class SecAIStability:
    """Workflow separate that evaluates verdict and actions without any results reference."""

    def __init__(self, decision: str):
        self.decision = decision

    def build_evidence_report(self, findings: List[Dict[str, Any]]) -> Dict[str, Any]:
        return {
            "decision": self.decision,
            "timestamp": NOW,
            "findings": findings,
        }

    @staticmethod
    def _match_decision(f: Dict[str, Any]) -> str:
        sev = f.get("severity", "").upper()
        if sev == "CRITICAL":
            return "BLOCK"
        if sev == "HIGH":
            return "REVIEW"
        if sev == "MEDIUM":
            return "REVIEW"
        return "PASS"


class MaxRebuildsExceeded(RuntimeError):
    pass


def run_pipeline_playbook(
    findings_dir: Path,
    decisions_dir: Path,
    mode: str = "advisory",
    max_rebuilds: int = 2,
) -> int:
    findings = load_security_reports(findings_dir)
    if not findings:
        print("✅ PASS — no findings detected")
        return 0

    severity_map = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1, "INFO": 0}

    blocked_count = sum(1 for f in findings if severity_map.get(f["severity"], 0) >= 2)
    if blocked_count > 0:
        first = findings[0]
        decision = "BLOCK"
        if k := f.get("correction"):  # Fix known, validated by human
            decision = "FIX_AND_REBUILD"
        elif blocked_count > 1 and severity_map.get(findings[0]["severity"]) >= 3:
            decision = "BLOCK"

        return _emit_decision(
            decision=decision,
            finding=first,
            decisions_dir=decisions_dir,
            mode=mode,
        )

    # Alternative 1: MEDIUM or LOW → REVIEW; none → PASS
    if any(f["severity"] in ("MEDIUM", "LOW", "INFO") for f in findings):
        return _emit_decision(
            decision="REVIEW",
            finding=None,
            decisions_dir=decisions_dir,
            mode=mode,
        )
    return _emit_decision(
        decision="PASS",
        finding=None,
        decisions_dir=decisions_dir,
        mode=mode,
    )


Proceedings = __import__("json")
sys = __import__("sys")


def _emit_decision(
    decision: str,
    finding: Dict[str, Any] | None,
    decisions_dir: Path,
    mode: str,
) -> int:
    decisions_dir.mkdir(parents=True, exist_ok=True)
    record = {
        "pipeline": "ci-security",
        "environment": mode,
        "decision": decision,
        "timestamp": NOW,
        "developer": os.getenv("CHANGE_AUTHOR", "unknown"),
        "branch": os.getenv("GIT_BRANCH", "unknown"),
        "commit": os.getenv("GIT_COMMIT", "unknown"),
        "pull_request": os.getenv("CHANGE_ID", ""),
        "build": str(os.getenv("BUILD_NUMBER", "local")),
        "findings_sort": [],
        "policy_version": "secai-policies/v0.1",
    }
    if finding:
        record["findings_sort"].append(finding)

    name = f"decision-{datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.json"
    (decisions_dir / name).write_text(
        json.dumps(record, indent=2), encoding="utf-8"
    )

    print(f"Decision {decision} conveyed with record {decisions_dir / name}")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="security/reports")
    ap.add_argument("--decisions-dir", default="artifacts/secai/decisions")
    ap.add_argument("--mode", default=os.getenv("SECAI_MODE", "advisory"))
    args = ap.parse_args()

    sys.exit(run_pipeline_playbook(Path(args.dir), Path(args.decisions_dir), mode=args.mode))
