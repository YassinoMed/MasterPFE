"""CLI de SECAI — utilisé par Jenkins.

Naturel… dépollue : les rapports existants sont lus, jamais ré-exécutés.
Le verdict influence la pipeline en mode Advisory ; en mode Strict, il bloque.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from secai.config import get_settings
from secai.pipelines.security_analysis import analyze_reports

logger = __import__("logging").getLogger("secai.cli")


def _render_md(report) -> str:
    lines = ["# SECAI — Rapport de Sécurité", ""]
    lines.append(f"- Généré : {report.summary.generated_at}")
    lines.append(f"- Verdict : **{report.summary.verdict.value}**")
    lines.append(f"- Total findings : {report.summary.total_findings}")
    lines.append("")
    lines.append("## Répartition par sévérité")
    for sev, cnt in sorted(report.summary.by_severity.items(), key=lambda x: -x[1]):
        if cnt:
            lines.append(f"- **{sev}** : {cnt}")
    lines.append("")
    lines.append("## Top findings (risk_score DESC)")
    lines.append("| Source | Sévérité | Titre | Explication |")
    lines.append("|---|---|---|---|")
    for f in sorted(report.findings, key=lambda x: -x.risk_score)[:15]:
        lines.append(f"| {f.source.value} | {f.severity.value} | {f.title[:80]} | {f.explanation[:160]} |")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="SECAI Security Analysis pipeline")
    ap.add_argument("--input", required=True, help="Répertoire avec rapports (semgrep.json, ... selon le secai-report).")
    ap.add_argument("--output", required=True, help="Fichier de sortie (json ou md).")
    ap.add_argument("--format", choices=["json", "md"], default="json")
    ap.add_argument("--images", default="", help="Comma-separated image names")
    args = ap.parse_args(argv)

    inp = Path(args.input)
    if not inp.exists():
        logger.warning("Input dir %s not found", inp)
        inp.mkdir(parents=True, exist_ok=True)

    files = [p for p in inp.iterdir() if p.is_file()]
    image_names = args.images.split(",") if args.images else []

    report = analyze_reports(files, image_names=image_names)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    if args.format == "json":
        out.write_text(report.model_dump_json(indent=2))
    else:
        out.write_text(_render_md(report))

    verdict = report.summary.verdict
    print(f"SECAI verdict: {verdict.value} ({report.summary.total_findings} findings)")

    if settings := get_settings():
        mode = settings.MODE
        if mode == "strict" and verdict == Decision.BLOCK:
            return 2
        if mode == "strict" and verdict == Decision.REVIEW:
            return 1
    # Advisory mode = always "report" (no blocking)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
