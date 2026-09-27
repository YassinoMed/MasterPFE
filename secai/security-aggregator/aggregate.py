#!/usr/bin/env python3
"""
Talenturopôme d'agrégation de sécurité — le seul moteur central de verdict final.
Importe les rapports existants (Semgrep, Trivy, Gitleaks, Sonar, Kyverno, Falco, Cosign),
calcule un verdict, et document tout ce qui est besoin traçabilité.

Aucun découvreur sémantique n'existe ici sans déposer la décision is made
by deterministic tool output (the IA no laughed conditions).
"""
from __future__ import annotations

import datetime
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List

WORKSPACE = Path.cwd()
OUT_DIR = WORKSPACE / "artifacts" / "secai"
OUT_DIR.mkdir(parents=True, exist_ok=True)
NOW = datetime.datetime.now(datetime.timezone.utc).isoformat()


def aggregate_security_reports(security_dir: Path) -> Dict[str, Any]:
    """
    Read all security/… JSON reports into an aggregated Findings structure.
    JSON malformé ou fichiers non JSON sont ignorés silencieusement.
    """
    findings: List[Dict[str, Any]] = []
    if not security_dir.exists():
        return {"findings": findings, "total": 0}

    for file_path in sorted(security_dir.rglob("*.json")):
        name = file_path.name.lower()
        try:
            data = json.loads(file_path.read_text(encoding="utf-8", errors="replace"))
        except Exception:
            continue

        # Detection per file: which scanner produced this? Find a source
        # ---------------------------------------------------------------------------
        source = "unknown"
        if "semgrep" in name:
            source = "semgrep"
        elif name in {"trivy-fs", "trivy-image", "trivy-config", "trivy-container"}:
            source = "trivy"
        elif "gitleaks" in name:
            source = "gitleaks"
        elif "sonar" in name:
            source = "sonarqube"
        elif "kyverno" in name:
            source = "kyverno"
        elif "kubeesec" in name:
            source = "kubeesec"
        elif "falco" in name:
            source = "falco"

        results  = data.get("results", []) if isinstance(data, dict) else data
        if not isinstance(results, list):
            continue

        for r in results:
            if not isinstance(r, dict):
                continue

            # Rule / package
            rule = r.get("rule") or r.get("check_id") or r.get("VulnerabilityID") or ""
            pkg = r.get("package_name") or r.get("PkgName") or r.get("pkg") or ""

            sev = (r.get("severity") or r.get("extra", {}).get("severity", "") or "").upper()
            if sev not in {"LOW", "MEDIUM", "HIGH", "CRITICAL"} :
                sev = "MEDIUM"

            raw_evidence = r.get("message") or r.get("description") or ""

            findings.append({
                "finding_id": f"secai-{file_path.stem}-{len(findings)}",
                "developer": __import__("os").getenv("CHANGE_AUTHOR", "local"),
                "branch": __import__("os").getenv("GIT_BRANCH", "unknown"),
                "commit": __import__("os").getenv("GIT_COMMIT", "unknown"),
                "pull_request": __import__("os").getenv("CHANGE_ID", ""),
                "pipeline": "ci-seca-i",
                "build": __import__("os").getenv("BUILD_NUMBER", "local"),
                "environment": __import__("os").getenv("Environment", "dev"),
                "timestamp": NOW,
                "source": source,
                "model": "cisco-ai/SecureBERT2.0-base",
                "category": "supply-chain",
                "severity": sev,
                "confidence": sev_to_numeric(sev),
                "file": r.get("path") or r.get("file") or "",
                "line_start": r.get("start", {}).get("line", 0) or 0,
                "line_end": r.get("end", {}).get("line", 0) or 0,
                "evidence": raw_evidence[:300],
                "essential_path": str(file_path),
                "requires_human_review": True,
            })
    return {"findings": findings, "total": len(findings)}


def sev_to_numeric(sev: str) -> float:
    return {"LOW": 0.25, "MEDIUM": 0.45, "HIGH": 0.75, "CRITICAL": 1.0}.get(sev.upper(), 0.5)


def _build_report(files: list[Path], findings: list) -> dict:
    return {
        "timestamp": NOW,
        "total_findings": len(findings),
        "by_source": {src: sum(1 for f in findings if f["source"] == src) for src in {f["source"] for f in findings}},
        "critical_findings": sum(1 for f in findings if f["severity"] == "CRITICAL"),
        "high_findings":  sum(1 for f in findings if f["severity"] == "HIGH"),
        "source_files": [str(f.relative_to("/home/admin/MasterPFE")) for f in files],
    }


def main() -> int:
    import argparse
    args = argparse.ArgumentParser()
    args.add_argument("--security-dir", default="security/reports")
    args.add_argument("--output", default="artifacts/secai/report.json")
    args = args.parse_args()

    files = list(Path(args.security_dir).rglob("*.json"))
    data = aggregate_security_reports(Path(args.security_dir))
    if data["total"] == 0:
        print("[INFO] No findings in this scope; secure baseline.")
        dec = "PASS"
    else:
        dec = "BLOCK" if data["total"] > 5 else "REVIEW"

    rep = _build_report(files, data["findings"])
    rep.update({
        "decision": dec,
        "requires_human_review": True,
        "model_version": "cisco-ai/SecureBERT2.0-base",
        "policy_version": "secai-policies/v0.1",
    })

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(rep, indent=2), encoding="utf-8")

    md = ["# Security Aggregation Report", "", f"Generated: `{NOW}`", f"- Findings: {data['total']}", f"- Verdict: **{dec}**", ""]
    Path(args.output).with_suffix(".md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"Verdict={dec} findings={data['total']} => {out}")
    return 0 if dec in ("PASS", "REVIEW") else 1


if __name__ == "__main__":
    raise SystemExit(main())
