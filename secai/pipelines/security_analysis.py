"""Pipeline principal SECAI — offline / batch.

Lit rapports générés par Semgrep/Trivy/Falco/Kyverno/Sonar,
applique normalisation déterministe et politique de décision,
puis enrichit chaque finding avec une explication basée sur gabarits fixes.
"""
from __future__ import annotations

import argparse
import logging
from pathlib import Path
from typing import List

from secai.api.schemas import (
    Decision,
    Finding,
    SecurityReport,
    SecuritySummary,
    Severity,
    Source,
)
from secai.config import get_settings
from secai.integrations.semgrep import parse_semgrep
from secai.integrations.trivy import parse_trivy
from secai.integrations.falco import parse_falco_text, parse_falco_json
from secai.integrations.kyverno import parse_kyverno
from secai.integrations.sonarqube import parse_sonarqube
from secai.policies.decision_policy import DecisionPolicy

logger = logging.getLogger("secai.pipelines.security_analysis")
settings = get_settings()

SEVERITY_WEIGHT = {
    Severity.CRITICAL: 1.0,
    Severity.HIGH: 0.75,
    Severity.MEDIUM: 0.4,
    Severity.LOW: 0.1,
}


def _normalize(f: Finding) -> Finding:
    f.risk_score = min(1.0, SEVERITY_WEIGHT.get(f.severity, 0.3) + (0.05 if f.evidence else 0))
    f.confidence = min(
        1.0,
        0.4
        + 0.3 * (1 if f.severity in {Severity.CRITICAL, Severity.HIGH} else 0)
        + 0.2 * (1 if len(f.evidence) >= 3 else 0),
    )
    f.decision = Decision.REVIEW if f.confidence >= 0.6 else Decision.INCONCLUSIVE
    f.requires_human_review = True
    return f


def _parse_one(p: Path, kind: str, image_names: List[str]) -> List[Finding]:
    logger.info("secai: parse %s (%s)", p, kind)
    if kind == "semgrep":
        return parse_semgrep(p)
    if kind == "trivy":
        return parse_trivy(p, ", ".join(image_names or ["unknown"]))
    if kind == "falco":
        if res := parse_falco_text(p):
            return res
        return parse_falco_json(p)
    if kind == "kyverno":
        return parse_kyverno(p)
    if kind == "sonar":
        return parse_sonarqube(p)
    return []


def analyze_reports(report_paths: List[Path], image_names: List[str] | None = None) -> SecurityReport:
    findings: List[Finding] = []
    for p in report_paths:
        name = p.name.lower()
        if "semgrep" in name:
            findings += _parse_one(p, "semgrep", image_names or [])
        elif "trivy" in name:
            findings += _parse_one(p, "trivy", image_names or [])
        elif "falco" in name:
            findings += _parse_one(p, "falco", image_names or [])
        elif "kyverno" in name:
            findings += _parse_one(p, "kyverno", image_names or [])
        elif "sonar" in name:
            findings += _parse_one(p, "sonar", image_names or [])
        else:
            logger.info("secai: skipped %s", p)

    normalized = [_normalize(f) for f in findings]

    from secai.pipelines.explanation import explain
    for f in normalized:
        f.explanation = explain(f)
        f.model_version = get_settings().MODEL_ID
        f.policy_version = "secai-policies/v0.1"
        f.requires_human_review = True

    summary = SecuritySummary(
        total_findings=len(normalized),
        by_severity={s.value: sum(1 for f in normalized if f.severity == s) for s in Severity},
        by_source={s.value: sum(1 for f in normalized if f.source == s) for s in Source},
        verdict=DecisionPolicy().decide(normalized),
    )
    return SecurityReport(summary=summary, findings=normalized)


def _render_md(report) -> str:
    lines = ["# SECAI — Rapport d'Analyse Sécurité", ""]
    lines.append(f"- Généré : `{report.summary.generated_at}`")
    lines.append(f"- Verdict : **{report.summary.verdict.value}**")
    lines.append(f"- Findings : {report.summary.total_findings}")
    lines.append("")
    lines.append("## Par sévérité")
    for sev, cnt in sorted(report.summary.by_severity.items(), key=lambda x: -x[1]):
        if cnt:
            lines.append(f"- **{sev}** : {cnt}")
    lines.append("")
    lines.append("## Top findings")
    lines.append("| Source | Sévérité | Explication |")
    lines.append("|---|---|---|")
    for f in sorted(report.findings, key=lambda x: -x.risk_score)[:15]:
        lines.append(f"| {f.source.value} | {f.severity.value} | {f.title[:80]} |")
    return "\n".join(lines) + "\n"


def main(argv: list | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--format", choices=["json", "md"], default="json")
    ap.add_argument("--images", default="", help="comma-separated image names")
    args = ap.parse_args(argv)

    inp = Path(args.input)
    if not inp.exists():
        inp.mkdir(parents=True, exist_ok=True)
    files = [p for p in inp.iterdir() if p.is_file()]
    image_names = args.images.split(",") if args.images else []

    report = analyze_reports(files, image_names=image_names)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    if args.format == "md":
        out.write_text(_render_md(report), encoding="utf-8")
    else:
        out.write_text(report.model_dump_json(indent=2), encoding="utf-8")

    verdict = report.summary.verdict
    print(f"SECAI: verdict={verdict.value} findings={report.summary.total_findings} → {out}")

    if get_settings().MODE == "strict" and verdict in {Decision.BLOCK, Decision.REVIEW}:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
