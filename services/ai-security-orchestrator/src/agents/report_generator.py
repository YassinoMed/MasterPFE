"""AI Report Generator — Unified security report generation."""
import structlog
from datetime import datetime, timezone
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import Dict, List, Optional

logger = structlog.get_logger()
report_router = APIRouter()


class ReportSection(BaseModel):
    title: str
    status: str  # PASS, WARNING, BLOCK
    score: float
    findings_count: int
    summary: str
    details: List[str] = Field(default_factory=list)


class ReportRequest(BaseModel):
    pipeline_id: str = Field("unknown")
    namespace: str = Field("securerag-hub")
    # Scores from each agent
    risk_score: float = Field(0.0)
    consensus_score: float = Field(0.0)
    decision: str = Field("PASS")
    # Agent results
    code_review_score: float = Field(0.0)
    code_review_findings: int = Field(0)
    docker_audit_score: float = Field(0.0)
    docker_audit_findings: int = Field(0)
    k8s_audit_score: float = Field(0.0)
    k8s_audit_findings: int = Field(0)
    threat_model_score: float = Field(0.0)
    threat_count: int = Field(0)
    runtime_score: float = Field(0.0)
    runtime_events: int = Field(0)
    metrics_score: float = Field(0.0)
    slo_violations: int = Field(0)
    # Supply chain
    sbom_present: bool = Field(True)
    cosign_verified: bool = Field(True)
    slsa_valid: bool = Field(True)


class ReportResponse(BaseModel):
    report_id: str
    timestamp: str
    pipeline_id: str
    overall_decision: str
    overall_risk_score: float
    overall_grade: str
    executive_summary: str
    sections: List[ReportSection]
    markdown_report: str


def _grade(score: float) -> str:
    if score >= 90: return "A+"
    if score >= 80: return "A"
    if score >= 70: return "B"
    if score >= 60: return "C"
    if score >= 50: return "D"
    return "F"


@report_router.post("/generate", response_model=ReportResponse)
async def generate_report(req: ReportRequest):
    """Generate unified AI DevSecOps security report."""
    logger.info("report_generation_started", pipeline=req.pipeline_id)

    now = datetime.now(timezone.utc)
    report_id = f"rpt-{now.strftime('%Y%m%dT%H%M%SZ')}"
    overall_security_score = 100 - req.risk_score
    grade = _grade(overall_security_score)

    sections = [
        ReportSection(
            title="Code Security (SAST)", status="PASS" if req.code_review_score < 30 else "WARNING",
            score=100 - req.code_review_score, findings_count=req.code_review_findings,
            summary=f"{req.code_review_findings} findings from Semgrep/SonarQube analysis",
        ),
        ReportSection(
            title="Container Security", status="PASS" if req.docker_audit_score < 30 else "WARNING",
            score=100 - req.docker_audit_score, findings_count=req.docker_audit_findings,
            summary=f"{req.docker_audit_findings} Dockerfile security findings",
        ),
        ReportSection(
            title="Kubernetes Security", status="PASS" if req.k8s_audit_score < 30 else "WARNING",
            score=100 - req.k8s_audit_score, findings_count=req.k8s_audit_findings,
            summary=f"{req.k8s_audit_findings} manifest security findings",
        ),
        ReportSection(
            title="Threat Model", status="PASS" if req.threat_model_score < 50 else "WARNING",
            score=100 - req.threat_model_score, findings_count=req.threat_count,
            summary=f"{req.threat_count} threats identified via STRIDE analysis",
        ),
        ReportSection(
            title="Runtime Security", status="PASS" if req.runtime_score < 30 else "WARNING",
            score=100 - req.runtime_score, findings_count=req.runtime_events,
            summary=f"{req.runtime_events} runtime security events detected",
        ),
        ReportSection(
            title="Metrics & SLO", status="PASS" if req.metrics_score < 25 else "WARNING",
            score=100 - req.metrics_score, findings_count=req.slo_violations,
            summary=f"{req.slo_violations} SLO violations detected",
        ),
        ReportSection(
            title="Supply Chain", status="PASS" if (req.sbom_present and req.cosign_verified and req.slsa_valid) else "BLOCK",
            score=100 if (req.sbom_present and req.cosign_verified and req.slsa_valid) else 0,
            findings_count=0 if (req.sbom_present and req.cosign_verified and req.slsa_valid) else 1,
            summary=f"SBOM: {'✅' if req.sbom_present else '❌'} | Cosign: {'✅' if req.cosign_verified else '❌'} | SLSA: {'✅' if req.slsa_valid else '❌'}",
        ),
    ]

    executive_summary = (
        f"AI-Native DevSecOps Security Report — Pipeline {req.pipeline_id}\n"
        f"Overall Grade: {grade} | Risk Score: {req.risk_score}/100 | "
        f"Consensus: {req.consensus_score}% | Decision: {req.decision}\n"
        f"Generated: {now.isoformat()}"
    )

    # Generate markdown
    md = f"# 🔒 AI-Native DevSecOps Security Report\n\n"
    md += f"**Pipeline**: {req.pipeline_id} | **Date**: {now.strftime('%Y-%m-%d %H:%M UTC')}\n\n"
    md += f"## Executive Summary\n\n"
    md += f"| Metric | Value |\n|--------|-------|\n"
    md += f"| Overall Grade | **{grade}** |\n"
    md += f"| Risk Score | {req.risk_score}/100 |\n"
    md += f"| Consensus | {req.consensus_score}% |\n"
    md += f"| Decision | **{req.decision}** |\n\n"
    md += f"## Security Domains\n\n"
    for s in sections:
        icon = "✅" if s.status == "PASS" else "⚠️" if s.status == "WARNING" else "❌"
        md += f"### {icon} {s.title}\n- Score: {s.score:.0f}/100\n- Findings: {s.findings_count}\n- {s.summary}\n\n"
    md += f"---\n*Report generated by AI Security Orchestrator v1.0.0*\n"

    return ReportResponse(
        report_id=report_id, timestamp=now.isoformat(),
        pipeline_id=req.pipeline_id, overall_decision=req.decision,
        overall_risk_score=req.risk_score, overall_grade=grade,
        executive_summary=executive_summary, sections=sections,
        markdown_report=md,
    )
