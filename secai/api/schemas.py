"""Pydantic models — le format canonique d'un Finding SECAI.

Toujours **JSON-sérialisable** (jamais de nuances internes) ; utilisé par
l'API, le pipeline et la persistance des rapports.
"""
from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any, List, Optional
from uuid import uuid4

from pydantic import BaseModel, Field, field_validator


class Source(str, Enum):
    semgrep = "semgrep"
    trivy = "trivy"
    falco = "falco"
    kyverno = "kyverno"
    sonarqube = "sonarqube"
    ci_failures = "ci_failures"
    other = "other"


class Severity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class Decision(str, Enum):
    PASS = "PASS"
    REVIEW = "REVIEW"
    BLOCK = "BLOCK"
    FIX_AND_REBUILD = "FIX_AND_REBUILD"
    INCONCLUSIVE = "INCONCLUSIVE"


class Finding(BaseModel):
    finding_id: str = Field(default_factory=lambda: str(uuid4()))
    source: Source = Source.other
    severity: Severity = Severity.MEDIUM
    category: str = "generic"
    rule_id: Optional[str] = None
    file_path: Optional[str] = None
    title: str = ""
    description: str = ""
    evidence: List[str] = Field(default_factory=list)
    confidence: float = 0.0
    risk_score: float = 0.0
    raw: dict[str, Any] = Field(default_factory=dict, exclude=True)

    # XAI + gate
    explanation: str = ""
    recommendation: str = ""
    decision: Decision = Decision.INCONCLUSIVE
    requires_human_review: bool = True
    model_version: str = ""
    policy_version: str = ""

    @field_validator("confidence", "risk_score")
    @classmethod
    def clamp_scores(cls, v: float) -> float:  # noqa: N805
        if isinstance(v, (int, float)):
            return max(0.0, min(1.0, float(v)))
        raise ValueError("score doit être un nombre")


class FindingList(BaseModel):
    findings: list[Finding]


class SecuritySummary(BaseModel):
    generated_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    total_findings: int
    by_severity: dict[str, int] = Field(default_factory=dict)
    by_source: dict[str, int] = Field(default_factory=dict)
    verdict: Decision = Decision.REVIEW
    version: str = "0.1.0"
    policy_version: str = "secai-policies/v0.1"


class SecurityReport(BaseModel):
    summary: SecuritySummary
    findings: List[Finding]
    warnings: List[str] = Field(default_factory=list)
    report_path: Optional[str] = None  # populated by the pipeline runner
