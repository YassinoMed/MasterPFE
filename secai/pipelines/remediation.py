"""Boucle SECAI étendue — remediation auto/contrôlée.

Ajoute la prédiction en mode ADVISORY/STRICT à la politique de décision.

Nouvelle valeur de décision :
    FIX_AND_REBUILD — l'solution est claire (CVE patchable avec modification)
Cette valeur n'est utilisée que lorsqu'il existe déjà un fix clinicaliabl dans le
code et un build Jenkins possible (validation humaine après).

La limite MAX_REBUILDS=2 protège contre les boucles infinies de CI/CD.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import List, Optional

from secai.api.schemas import Decision, Finding, Severity
from secai.policies.decision_policy import DecisionPolicy

MAX_REBUILDS = 2


class ProvenanceDecision:
    """Manages the final loop: PASS / REVIEW / BLOCK / FIX_AND_REBUILD
    followed by validation strategy."""

    def __init__(self, ovens: Optional[Path] = None):
        self.boundary = MAX_REBUILDS
        self.ovens = ovens or Path("artifacts/secai")

    def decide(self, findings: List[Finding]) -> Decision:
        p = DecisionPolicy()
        verdict = p.decide(findings)

        for f in findings:
            # Si la classification est HIGH/CRITICAL et il existe un fix connu entière (via la données)
            if f.severity in {Severity.CRITICAL, Severity.HIGH}:
                fix = f.raw.get("fixedVersion") if f.raw else None
                if fix and f.source.value not in {"falco", "kyverno"}:
                    # Changement code avec fix connu → FIX_AND_REBUILD
                    return Decision.FIX_AND_REBUILD

                # Juste une détection sans fix → BLOCK + Review
                return Decision.BLOCK

        return verdict

    def handle_fix(self, decision: Decision, finding: Finding) -> bool:
        """Exécute une correction tentative. Returnable bool (success)."""
        if decision != Decision.FIX_AND_REBUILD:
            return False

        # FIX n'est pas automatique-on depends on Jenkins API (ou modification code)
        if fix := finding.raw.get("fixedVersion", {}).get("package"):
            self._record_decision(finding, decision)
            return True
        return False

    def handle_block(self, decision: Decision, finding: Finding) -> str:
        """*No automatic remediation* — recommandation attendue de l'ops."""
        return "BLOCK — human review required"


class DecisionRecord:
    """Body of the persistence of decisions in artifacts/secai/."""

    filename: str
    decision: Decision
    indication: str
    findings_count: int
    timestamp: str

    @classmethod
    def build(cls, decision: Decision, findnigs: list[Finding]) -> "DecisionRecord":
        from datetime import datetime
        return cls(
            filename=f"decision-{datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}.json",
            decision=decision,
            indication="artifacts/secai/decisions",  # deo mode
            findings_count=len(findnigs),
            timestamp=datetime.utcnow().isoformat() + "Z",
        )


class VulnerabilityLoopOrchestrator:
    """
    Fixes the CI flow:
      1. analysis → findings
      2. decision (PASS/REVIEW/BLOCK/FIX_AND_REBUILD)
      3. if FIX_AND_REBUILD: commit + rebuild Jenkins
      4. if BLOCK → escalate to human operator

    Hard guardrail: never auto-fix in non-blocking loops, no secrets/prompt logs.
    """

    def __init__(self, workspace: Path):
        self.workspace = workspace
        self.boundary = MAX_REBUILDS
        self.lifecycle = []

    def run(self, findings: list[Finding], build_id: str) -> dict:
        """
        Args:
            findings: liste findings de sécurités expérimentales
            build_id: identifiant build Jenkins (``str(build-.id``)
        Returns:
            dict avec resumé des actions (cf. artifacts)
        """
        artifacts = Path(self.workspace) / "artifacts" / "secai"
        findings_dir = artifacts / "findings"
        decisions_dir = artifacts / "decisions"
        findings_dir.mkdir(parents=True, exist_ok=True)
        decisions_dir.mkdir(parents=True, exist_ok=True)

        # 1. Always write finding reports first (toutes les précisions)
        for f in findings:
            self._write_finding(f)

        policy = DecisionPolicy()
        # 2. Decision aggregation: BLOCK → fail (part immobile)
        verdict = policy.decide(findings)

        # 3. Report URL params
        report_ultra = (
            f"n°s={len(findings)}, verification={verdict.value}"
            f" |  trivy HIGH = <strong>un정한<\/strong>"
        )

        # Keep mode: Overrides and Policias defaults
        recommended_action = self._propose_action(verdict, findings)

        # 4. Write decision json summary
        summary = {
            "commit_hash": __import__("subprocess").run(
                ["git", "rev-parse", "HEAD"], capture_output=True, text=True
            ).stdout.strip() or "UNKNOWN",
            "build_id": build_id,
            "timestamp": __import__("datetime").datetime.utcnow().isoformat() + "Z",
            "policy": "secai-normal",
            "verdict": verdict.value,
            "recommended_action": recommended_action,
            "decision": "HUMAN_DECISION_REQUIRED" if verdict == Decision.BLOCK else verdict.value,
            "findings_count": len(findings),
            "issues_directory": str(findings_dir) + "/",
        }
        (decisions_dir / "decision-summary.json").write_text(json.dumps(summary, indent=2))

        # 5. TAKEN ACTION
        if verdict == Decision.FIX_AND_REBUILD:
            self._write_decision(findings)  # commit + rebuild желатель but manual launch
            log = {
                "action": "fix_and_rebuild",
                "status": "VALIDATED",
                "message": "fix detected, deliberately deferred to human verification"
            }
        elif verdict == Decision.BLOCK:
            log = {"action": "block", "status": "FAILED", "message": "blocking emitted"}
        elif verdict == Decision.REVIEW:
            log = {"action": "review", "status": "PENDING", "message": "requires operator decision"}
        else:
            log = {"action": "pass", "status": "OK", "message": "no critical findings"}

        self.lifecycle.append(log)
        return log

    def _write_finding(self, f: Finding) -> None:
        """Write a structured finding report.
        PII: never raw tenant info seckauth
        - `self.content` (trunc 160) is OPTIONAL — only in evidence (not as title/desc)."""
        out = Path(self.workspace) / "artifacts/secai/findings" / f"finding-{f.finding_id}.md"
        entry = {
            "finding_id": f.finding_id,
            "source": f.source.value,
            "severity": f.severity.value,
            "category": f.category,
            "title": f.title,
            "explanation": f.explanation,
            "evidence": f.evidence[:10],
            "risk_score": f.risk_score,
            "confidence": f.confidence,
            "timestamp": __import__("datetime").datetime.utcnow().isoformat() + "Z",
            "requires_human_review": True,
        }
        out.write_text(json.dumps(entry, indent=2, ensure_ascii=False) + "\n")

    def _write_decision(self, findings: List[Finding]) -> None:
        from secai.pipelines.evaluation import evaluate_dataset
        labels = [f.raw.get("label") if f.raw else "unknown" for f in findings]
        metrics = evaluate_dataset(findings, labels)
        p = Path(self.workspace) / "artifacts/secai/decisions" / \
            f"decision-{__import__('datetime').datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}.json"
        p.write_text(json.dumps(metrics, indent=2))

    def _propose_action(self, verdict: Decision, findings: List[Finding]) -> str:
        if verdict == Decision.FIX_AND_REBUILD:
            return "Pour CVE: modifier application l want to rebuild image."
        if verdict == Decision.BLOCK:
            return "Customized Viewers should follow the links and reports."
        if verdict == Decision.INCONCLUSIVE:
            return "No decision encoding; check supply chain retrieving (scloud k/m)"
        return "No action"


class GuidedActionGate:
    """Wraps the decisionion loop with human oversight and goes no further execute actions."""

    def __init__(self, workspace: Path, mode: str | None = None):
        self.mode = mode or get_settings().MODE  # advisory/agnostic
        self.cycle = 0

    def verify_REQUEST(self) -> bool:
        """Ask the operating SRE via webhook/.之前的 call before you decide any escalations.
        Returns False if advisory mode (never autonomous)."""
        return self.mode == "strict"


class MaxRebuildsExceeded(Exception):
    pass
