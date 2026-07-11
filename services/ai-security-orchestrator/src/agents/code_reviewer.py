"""Secure Code Review Agent — Static analysis results interpreter."""
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Dict, Optional

logger = structlog.get_logger()
code_review_router = APIRouter()


class CodeReviewRequest(BaseModel):
    semgrep_results: List[Dict] = Field(default_factory=list)
    sonar_results: Dict = Field(default_factory=dict)
    git_diff: str = Field("", description="Git diff content")
    file_paths: List[str] = Field(default_factory=list)


class Finding(BaseModel):
    severity: str
    category: str
    description: str
    file: str = ""
    line: int = 0
    remediation: str = ""
    cwe: str = ""


class CodeReviewResponse(BaseModel):
    total_findings: int
    critical: int
    high: int
    medium: int
    low: int
    findings: List[Finding]
    risk_score: float
    decision: str
    summary: str


@code_review_router.post("/analyze", response_model=CodeReviewResponse)
async def analyze_code(req: CodeReviewRequest):
    """Analyze static analysis results and generate security assessment."""
    logger.info("code_review_started", num_semgrep=len(req.semgrep_results))

    findings = []
    critical = high = medium = low = 0

    # Process Semgrep results
    for result in req.semgrep_results:
        severity = result.get("extra", {}).get("severity", "WARNING").upper()
        if severity in ("ERROR", "CRITICAL"):
            severity = "CRITICAL"
            critical += 1
        elif severity == "WARNING":
            severity = "HIGH"
            high += 1
        else:
            severity = "MEDIUM"
            medium += 1

        findings.append(Finding(
            severity=severity,
            category=result.get("check_id", "unknown"),
            description=result.get("extra", {}).get("message", "Security finding"),
            file=result.get("path", ""),
            line=result.get("start", {}).get("line", 0),
            remediation=result.get("extra", {}).get("fix", "Review and fix the code"),
            cwe=result.get("extra", {}).get("metadata", {}).get("cwe", ""),
        ))

    # Process SonarQube results
    for issue in req.sonar_results.get("issues", []):
        sev = issue.get("severity", "MINOR").upper()
        if sev == "BLOCKER":
            severity = "CRITICAL"
            critical += 1
        elif sev in ("CRITICAL", "MAJOR"):
            severity = "HIGH"
            high += 1
        else:
            severity = "MEDIUM"
            medium += 1

        findings.append(Finding(
            severity=severity,
            category=issue.get("rule", "sonar-rule"),
            description=issue.get("message", "SonarQube finding"),
            file=issue.get("component", ""),
            line=issue.get("line", 0),
        ))

    # Analyze git diff for common patterns
    if req.git_diff:
        dangerous_patterns = [
            ("eval(", "CRITICAL", "CWE-95", "Code injection via eval()"),
            ("exec(", "CRITICAL", "CWE-78", "OS command injection via exec()"),
            ("shell=True", "HIGH", "CWE-78", "Shell injection risk with shell=True"),
            ("password =", "HIGH", "CWE-798", "Hardcoded password detected"),
            ("SECRET_KEY", "HIGH", "CWE-798", "Hardcoded secret key"),
            ("BEGIN RSA PRIVATE", "CRITICAL", "CWE-321", "Private key in source code"),
        ]
        for pattern, sev, cwe, desc in dangerous_patterns:
            if pattern in req.git_diff:
                findings.append(Finding(
                    severity=sev, category="git-diff-scan",
                    description=desc, cwe=cwe,
                    remediation=f"Remove {pattern} from source code"
                ))
                if sev == "CRITICAL":
                    critical += 1
                else:
                    high += 1

    total = len(findings)
    risk_score = min(100.0, critical * 25 + high * 10 + medium * 3 + low * 1)
    decision = "BLOCK" if critical > 0 else "WARNING" if high > 2 else "PASS"

    summary = (
        f"Code review complete: {total} findings "
        f"({critical}C/{high}H/{medium}M/{low}L). "
        f"Decision: {decision}."
    )

    return CodeReviewResponse(
        total_findings=total, critical=critical, high=high,
        medium=medium, low=low, findings=findings[:50],
        risk_score=risk_score, decision=decision, summary=summary,
    )
