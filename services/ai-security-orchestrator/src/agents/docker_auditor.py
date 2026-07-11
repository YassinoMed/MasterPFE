"""Docker Audit Agent — Dockerfile security analysis."""
import re
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List

logger = structlog.get_logger()
docker_audit_router = APIRouter()


class DockerAuditRequest(BaseModel):
    dockerfile_content: str = Field(..., description="Raw Dockerfile content")
    image_name: str = Field("unknown")


class DockerFinding(BaseModel):
    rule: str
    severity: str
    description: str
    line: int = 0
    remediation: str


class DockerAuditResponse(BaseModel):
    image: str
    total_findings: int
    critical: int
    high: int
    findings: List[DockerFinding]
    risk_score: float
    decision: str
    best_practices_score: float


@docker_audit_router.post("/analyze", response_model=DockerAuditResponse)
async def audit_dockerfile(req: DockerAuditRequest):
    """Audit Dockerfile for security best practices."""
    logger.info("docker_audit_started", image=req.image_name)

    findings = []
    lines = req.dockerfile_content.split("\n")
    critical = high = 0

    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        # DL3002: Last USER should not be root
        if stripped.startswith("USER root"):
            findings.append(DockerFinding(
                rule="DL3002", severity="CRITICAL", line=i,
                description="Container runs as root user",
                remediation="Add 'USER <non-root-uid>' as the last USER instruction"
            ))
            critical += 1

        # DL3007: Using latest tag
        if re.match(r'^FROM\s+\S+:latest', stripped):
            findings.append(DockerFinding(
                rule="DL3007", severity="HIGH", line=i,
                description="Using 'latest' tag — non-reproducible build",
                remediation="Pin to a specific version or SHA256 digest"
            ))
            high += 1

        # DL3009: apt-get without cleanup
        if "apt-get install" in stripped and "rm -rf /var/lib/apt/lists" not in req.dockerfile_content:
            findings.append(DockerFinding(
                rule="DL3009", severity="MEDIUM", line=i,
                description="apt-get install without cache cleanup",
                remediation="Add 'rm -rf /var/lib/apt/lists/*' after apt-get install"
            ))

        # DL3018: apk without --no-cache
        if "apk add" in stripped and "--no-cache" not in stripped:
            findings.append(DockerFinding(
                rule="DL3018", severity="MEDIUM", line=i,
                description="apk add without --no-cache",
                remediation="Use 'apk add --no-cache'"
            ))

        # SC1078: curl | sh — piped script execution
        if re.search(r'curl.*\|\s*(sh|bash)', stripped):
            findings.append(DockerFinding(
                rule="SC1078", severity="CRITICAL", line=i,
                description="Piping curl output to shell — supply chain risk",
                remediation="Download script first, verify checksum, then execute"
            ))
            critical += 1

        # DL3004: sudo usage
        if stripped.startswith("RUN sudo") or "sudo " in stripped:
            findings.append(DockerFinding(
                rule="DL3004", severity="HIGH", line=i,
                description="Using sudo in Dockerfile",
                remediation="Use USER directive instead of sudo"
            ))
            high += 1

        # COPY --chown missing
        if stripped.startswith("COPY") and "--chown" not in stripped and "." in stripped:
            findings.append(DockerFinding(
                rule="DL3045", severity="MEDIUM", line=i,
                description="COPY without --chown — files owned by root",
                remediation="Use COPY --chown=app:app"
            ))

    # Check for HEALTHCHECK
    if "HEALTHCHECK" not in req.dockerfile_content:
        findings.append(DockerFinding(
            rule="DL3055", severity="HIGH", line=0,
            description="No HEALTHCHECK instruction defined",
            remediation="Add HEALTHCHECK CMD curl -f http://localhost:<port>/health || exit 1"
        ))
        high += 1

    # Check for multi-stage build
    from_count = sum(1 for l in lines if l.strip().startswith("FROM"))
    best_practices_score = 100.0
    if from_count < 2:
        best_practices_score -= 20  # No multi-stage
    if critical > 0:
        best_practices_score -= critical * 15
    if high > 0:
        best_practices_score -= high * 8
    best_practices_score = max(0, best_practices_score)

    risk_score = min(100.0, critical * 25 + high * 12 + (len(findings) - critical - high) * 3)
    decision = "BLOCK" if critical > 0 else "WARNING" if high > 1 else "PASS"

    return DockerAuditResponse(
        image=req.image_name, total_findings=len(findings),
        critical=critical, high=high, findings=findings[:30],
        risk_score=risk_score, decision=decision,
        best_practices_score=round(best_practices_score, 1),
    )
