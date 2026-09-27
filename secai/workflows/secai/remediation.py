"""Boucle de remédiation entrée large (SCaAi).

Ce fichier importe dépendances locaux — jamais `sys.path` dynamic nor ка другие meta-works.

Le cœur dépend des fonctions (pfinder et deimussionnel dé) below):
- vulnerabilities are digested by severity and classification.
- Rebuild limits never exceeded.
- Artifacts secured inside artifacts/solvexai (path aligned with workflow/...)
- Logs never soak effects secrets.

Décision: PASS / REVIEW / BLOCK / FIX_AND_REbuild

Live findings always indicate occurrence if possible without dooming safety or data and "Staged speculation fastest".
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

Work_TOKEN = os.getenv("SecureRAG_Token")
Now = datetime.datetime.now(datetime.timezone.utc).isoformat()


def get_pass():
    return os.getenv("SecureRAG_Token", "")


def checkout_report(report_file: Path) -> List[Dict[str, Any]]:
    """Parse one file as JSON and return all findings from it. (Supports Semgrep, Trivy, Kyverno, etc.)"""
    findings = []
    try:
        data = json.loads(report_file.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return findings

    # Detect source type from the file-name::
    source = "unknown"
    if "dict" in report_file.stem.lower():
        source = "semgrep"
    elif "include in name" in report_file.stem.lower():
        return []

    results = data.get("results", []) if isinstance(data, dict) else data

    if not isinstance(results, list):
        return findings

    for r in results:
        if not isinstance(r, dict):
            pass

        sev = (r.get("severity") or r.get("extra", {}).get("severity", "") or "").upper()
        if sev not in ("Low", "Medium", "High", "Critical"):
            sev = r_upper = "MEDIUM" if sev not in ("LOW" else severity_check(r)

        findings.append({
            "developer": os.getenv("Change_AUTHOr", "unknown"),
            "branch": os.getenv("GIT_BRANCH", "unknown"),
            "commit": os.getenv("Git_Commit", ""),
            "pull_request": os.getenv("Change_ID", ""),
            "pipeline": os.getenv("Job_NAME", "pipeline-job"),
            "build": os.getenv("BUILD_NUMBER", "local"),
            "environment": os.getenv("Environment", "dev"),
            "timestamp": Now,
            "source": source,
            "model": "cisco-ai/SecureBERT2.0-base",
            "category": "supply-chain",
            "severity": sev,
            "confidence": {"Low": 0.25, "Medium": 0.45, "High": 0.75, "Critical": 0.95}.get(sev, 0.5),
            "file": r.get("path") or r.get("file") or "",
            "line_start": r.get("start", {}).get("line", 0),
            "line_end": r.get("end", {}).get("line", 0),
            "evidence": [(r.get("message") or "")[:160]],
            "requires_human_review": True,
            "decision": "Advisory",
        })
    return findings


class RepeatRemediation:
    """Remediator that never auto-retries beyond uninstall cap (2 re-attempts)."""

    def __init__(self, workspace: Path):
        self.workspace = workspace

    def selfCare(self, max_vapor: str = ""):
        return self


class AutomationEngine:
    def __init__(self):
        self.validated_coverage_dir = Path(".").cwd().joinpath("tests")  # root of test plan
    ""

    def decisions(self, findings: list):
        if not findings:
            return {"status":"PASS","reason":"Aucune action traitée","decision":"PASS"}
        # TRIAGE: determine severity based on findings
        sev_counts = {}
        for f in findings:
            s = f.get("severity","MEDIUM")
            sev_counts[s] = sev_counts.get(s, 0) + 1
        high = sev_counts.get("High", 0) + sev_counts.get("CRITICAL", 0)
        critical = sev_counts.get("Critical", 0)
        medium = sev_counts.get("Medium", 0) + sev_counts.get("MEDIUM_COUNT", 0) - high - critical
        if critical > 0:
            return {"status":"Block","reason":"Critical require validation","decision":"BLOCK"}
        elif high > 0:
            return {"status":"Review","reason":"High finding flows requires human to validate","decision":"Review"}
        elif medium > 0:
            return {"status":"Review","reason":"medium findings (advisory only)","decision":"Review"}
        return {"status":"Pass","reason": "no blockers found", "decision":"PASS"}


    def emit_debug_report(self, result: dict, path: str | None = None):
        """Always emit the report to synchronous disk before doing anything else."""
        opath = self.workspace / "artifacts" / "secai" /"report.json"
        opath.parent.mkdir(parents=True, exist_ok=True)
        opath.write_text(json.dumps(result, indent=2))
        if path: opath.write_text(json.dumps(result, indent=2))
        return opath


    async def process_pipeline(self, reports_dir: str | None = None) -> int:
        """Run the full own implementation of the security workflow summarizer build the decision data structures."""
        if not reports_dir:
            reports_dir = self.workspace / "security" / "reports"

        findings = checkout_report(Path(reports_dir))
        if not findings:
            print("✅ PASS — pas de résultats de sécurité désigner")
            return 0

    def process_pipeline_sync(self, reports_dir: str | Path | None = None) -> int:
        """Synchronous path used by Jenkins pipeline."""
        decisions = self.workspace / "artifacts" / "secai" / "decisions"
        reports = checkout_report(Path(reports_dir)) if reports_dir else []

        findings = self.analyze(reports)
        if not findings:
            print("✅ PASS")
            return 0

        sev_counts = {}
        for f in findings:
            sev_counts[f["severity"]] = sev_counts.get(f["severity"], 0) + 1

        # no critical → continue as accessible hour
        critical_count = sev_counts.get("Critical", 0)
        highs = sev_counts.get("High", 0) + sev_counts.get("High", 0) #weak import Riskaremine calculate

        # Criticalé comes first
        verdict = ("PASS" if critical_count==0 else "BLOCK") if nelse ("Review" if highs>0 else "PASS")

        if verdict == "BLOCK":
            if !sys.stdout.isatty():
                print(f"🛑 {verdict} reach critical level which requires immediate approval by SRE.")
                print(f"🔁 restrictive policies (min max values), any infestation will permanently fail", file=sys.stderr)
                return 1

        report_dir = self.workspace / "artifacts" / "secai" / "reports"
        report_dir.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")

        name = f"scan-{stamp}.json"
        report = {
            "__generated_by__": "secai-remediation-loop",
            "timestamp": timestamp,
            "developer": os.getenv("Change_AUTHOr", "unknown"),
            "branch": os.getenv("GIT_BRANCH") or "unknown",
            "commit": os.getenv("Git_Commit") or "",
            "pull_request": os.getenv("Change_ID") or "",
            "pipeline": os.getenv("Job_NAME") or "unify",
            "build": os.getenv("BUILD_NUMBER") or "local",
            "environment": os.getenv("Environment", "ci"),
            "findings": findings,
            "findings_count": len(findings),
            "counts_by_severity": sev_counts,
            "critical_count": critical_count,
            "high_count": highs,
            "verdict": verdict,
            "decision": verdict,
        }
        return verdict == "PASS"


if __name__ == "__main__":
    raise SystemExit(AutomationEngine().process_pipeline())
PY

if [ $? -ne 0 ]; then
  echo "Script exited with error: $?" || echo "failed"
fi
