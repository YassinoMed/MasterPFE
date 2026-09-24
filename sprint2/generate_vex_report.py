#!/usr/bin/env python3
"""Generate VEX report from Trivy scan — NOT fabricate analysis.

Deterministic processing: classifies by severity, counts HIGH/CRITICAL,
and outputs JSON/Markdown. SECAI (or human reviewers) provide the
explanations separately and explicitly — no fabricated analysis.

Run: python3 sprint2/generate_vex_report.py \
       --input security/reports/trivy-image-portal-web.json \
       --image localhost:5001/securerag-hub-portal-web:dev \
       --output artifacts/release/vex-analysis.json
"""
import argparse
import json
import sys
from pathlib import Path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--image", required=True)
    ap.add_argument("--output", default="artifacts/release/vex-analysis.json")
    args = ap.parse_args()

    file_path = Path(args.input)
    if not file_path.exists():
        print(f"[ERROR] input file missing: {file_path}", file=sys.stderr)
        return 1

    d = json.loads(file_path.read_text())
    summaries = d.get("Results", [])
    findings = []
    for r in summaries:
        for v in r.get("Vulnerabilities", []) or []:
            sev = (v.get("Severity") or "").upper()
            findings.append({
                "cve": v.get("VulnerabilityID"),
                "package": v.get("PkgName"),
                "severity": sev,
                "installed": v.get("InstalledVersion"),
                "fixed": v.get("FixedVersion", ""),
                "title": f"{sev} — {v.get('PkgName')} {v.get('InstalledVersion')} → {v.get('FixedVersion','?')}",
                "cve_id": v.get("VulnerabilityID"),
                "url": v.get("PrimaryURL", ""),
            })

    n_crit = sum(1 for f in findings if f["severity"] == "CRITICAL")
    n_high = sum(1 for f in findings if f["severity"] == "HIGH")
    n_med  = sum(1 for f in findings if f["severity"] == "MEDIUM")
    n_low  = sum(1 for f in findings if f["severity"] == "LOW")

    # Découverte humaine — jamais ignorer par IA
    verdict = "BLOCK" if n_crit else ("REVIEW" if n_high else "PASS")

    report = {
        "timestamp": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat(),
        "tool": "trivy",
        "image": args.image,
        "source_file": str(file_path),
        "total_findings": len(findings),
        "counts": {"critical": n_crit, "high": n_high, "medium": n_med, "low": n_low},
        "verdict": verdict,
        "requires_human_review": True,  # NEVER unattendedly ignore a HIGH/CRITICAL via AI
        "findings": findings,
    }

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(json.dumps(report, indent=2))
    print(f"[OK] {args.output} — verdict={verdict} total={len(findings)} crit={n_crit} high={n_high}")

    # Also emit a markdown slide-friendly version
    md_path = Path(args.output).with_suffix('.md')
    md = [f"# VEX Analysis — `{report['image']}`", ""]
    md += [f"- Date: `{report['timestamp']}`",
           f"- Verdict: **{verdict}**",
           f"- Criticité: {n_crit} · Haute: {n_high} · Moyenne: {n_med} · Faible: {n_low}",
           "", "## Findings"]
    md.append("| CVE | Severity | Package | Fixed | Title |")
    md.append("|---|---|---|---|---|")
    for f in findings:
        md.append(f"| {f['cve_id']} | {f['severity']} | {f['package']} | {f['fixed'] or '-'} | {f['title'][:80]} |")
    md_path.write_text("\n".join(md))
    print(f"[OK] Markdown: {md_path}")


if __name__ == '__main__':
    raise SystemExit(main())
