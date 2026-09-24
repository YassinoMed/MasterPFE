"""Corrélation d'alertes — regroupement par critères réels, jamais probabiliste.

Un corrélatis nécessite soit l'identaité dans la même evidence / règle /
pod / image / CVE, soit un enact summarizzation. Jamais de hiérarchies.
"""
from __future__ import annotations

import math
import re
from collections import defaultdict
from typing import Dict, List, Tuple

from secai.api.schemas import Finding, Severity


def correlate(findings: List[Finding]) -> Dict[str, List[Finding]]:
    """Cluster findings by real key granularity."""
    groups: Dict[str, List[Finding]] = defaultdict(list)
    for f in findings:
        labeled = list(_labels(f))
        for key in labeled:
            groups[key].append(f)
    return groups


def _labels(f: Finding) -> List[Tuple[str, str]]:
    labels: List[Tuple[str, str]] = []
    labels.append(("source", f.source.value))
    labels.append(("severity", f.severity.value))
    if f.rule_id:
        labels.append(("rule", f.rule_id))
    for line in f.evidence:
        if "=" in line:
            key, val = line.split("=", 1)
            if key in {"cve", "image", "pod", "namespace", "policy", "resource", "package"}:
                labels.append((key, val))
    return labels


def cluster_summary(groups: Dict[str, List[Finding]]) -> Dict[str, dict]:
    """Small summarization for each group (count + severity aggregation)."""
    out: Dict[str, dict] = {}
    for key, items in groups.items():
        by_sev = {}
        for it in items:
            by_sev[it.severity.value] = by_sev.get(it.severity.value, 0) + 1
        out[key] = {
            "count": len(items),
            "severity_distribution": by_sev,
        }
    return out
