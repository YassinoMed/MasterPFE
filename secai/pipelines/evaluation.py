"""Evaluation framework SECAI — métriques, seuils, tests.

Ici on utilise la similarité embeddings (pas classifier) et on applique des seuls
heuristiques > testées avec un dataset annoté. Aucun seuil n'est 'inventé' avant
d'avoir un score équivalentien d'un vrai dataset et validation humaine.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List, Tuple

from secai.api.schemas import Decision, Finding, Severity, Source
from secai.models.securebert_loader import SecureBERTLoader
from secai.policies.decision_policy import DecisionPolicy


def evaluate_dataset(entries: List[Finding], reference_labels: List[str]) -> dict:
    """Mesure TP/TN/FP/FN selon les labels annotés.

    reference_labels[i] = 'positive' | 'negative' | 'borderline' pour entries[i].
    On déclare positive si décision == BLOCK.
    """
    decisions = [entries[i].decision for i in range(len(entries))]

    tp = sum(1 for lab, d in zip(reference_labels, decisions) if lab == "positive" and d == Decision.BLOCK)
    tn = sum(1 for lab, d in zip(reference_labels, decisions) if lab == "negative" and d != Decision.BLOCK)
    fp = sum(1 for lab, d in zip(reference_labels, decisions) if lab in ("negative", "borderline") and d == Decision.BLOCK)
    fn = sum(1 for lab, d in zip(reference_labels, decisions) if lab == "positive" and d != Decision.BLOCK)

    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0
    fpr = fp / (fp + tn) if (fp + tn) else 0.0
    fnr = fn / (fn + tp) if (fn + tp) else 0.0

    return {
        "tp": tp, "tn": tn, "fp": fp, "fn": fn,
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
        "false_positive_rate": round(fpr, 4),
        "false_negative_rate": round(fnr, 4),
        "total": len(entries),
    }


def classify_findings(findings: List[Finding], policy: DecisionPolicy) -> None:
    """Applique la politique de décision sur chaque finding."""
    for f in findings:
        f.decision = policy.decide([f])


def evaluate_fixture(json_path: Path) -> dict:
    raw = json.loads(Path(json_path).read_text())
    findings: List[Finding] = []
    labels: List[str] = []
    for entry in raw:
        sev = entry.get("severity", "medium").upper()
        f = Finding(
            source=Source(entry.get("source", "other")),
            severity=Severity(sev) if sev in Severity.__members__ else Severity.MEDIUM,
            rule_id=entry.get("rule_id", "unknown"),
            title=(entry.get("content") or "")[:160],
            description=(entry.get("content") or "")[:500],
            evidence=[f"id={entry['id']}", f"label={entry['label']}"],
            raw={"content": entry["content"][:200], "id": entry["id"], "label": entry["label"]},
            requires_human_review=True,
            confidence=1.0,
        )
        findings.append(f)
        labels.append(entry["label"])

    classify_findings(findings, DecisionPolicy())
    metrics = evaluate_dataset(findings, labels)
    return metrics


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", default=None)
    args = ap.parse_args()
    metrics = evaluate_fixture(Path(args.input))
    print(json.dumps(metrics, indent=2))
    if args.output:
        Path(args.output).write_text(json.dumps(metrics, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
