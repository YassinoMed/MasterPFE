"""VEX report generation — *pas* d'IA masquée, du vrai traitement.

Chaque vulnérabilité est :
  1. Filtrée par sévérité (HIGH/CRITICAL n'excluent pas les MEDIUM/LOW).
  2. Analysée via la template XAI deterministic.
  3. Décisionnelle par règles déterministes (never AI blocking).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, List

from secai.api.schemas import Decision, Finding, Severity
from secai.integrations.trivy import parse_trivy
from secai.pipelines.explanation import explain
from secai.policies.decision_policy import DecisionPolicy


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--image", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args(argv)

    findings: List[Finding] = parse_trivy(Path(args.input), image_name=args.image)

    if not findings:
        print("[INFO] No findings in input.")
        return 0

    for f in findings:
        # analyse déterministe, pas de modèle IA ici
        f.explanation = explain(f)
        f.policy_version = "secai-policies/v0.1"
        f.requires_human_review = True

    policy = DecisionPolicy()

    # Group by and categorise
    severities = {}
    for f in findings:
        severities[f.severity.value] = severities.get(f.severity.value, 0) + 1

    verdict = policy.decide(findings)

    report = {
        "timestamp": __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).isoformat(),
        "source": "trivy",
        "image": args.image,
        "total_findings": len(findings),
        "severity_counts": severities,
        "verdict": verdict.value,
        "policy_version": policy.policy_version,
        "requires_human_review": True,
        "findings": [f.model_dump(exclude={"raw"}) for f in findings],
    }

    Path(args.output).write_text(json.dumps(report, indent=2))
    print(f"[INFO] VEX report: {args.output} (verdict={verdict.value}, findings={len(findings)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
