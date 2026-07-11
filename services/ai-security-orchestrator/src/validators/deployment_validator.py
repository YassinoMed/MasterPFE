"""Deployment Validator — Pre-deployment security gate."""
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List

logger = structlog.get_logger()
deployment_validator_router = APIRouter()


class DeploymentValidationRequest(BaseModel):
    namespace: str = Field("securerag-hub")
    service: str = Field("unknown")
    image: str = Field("")
    cosign_verified: bool = Field(False)
    sbom_present: bool = Field(False)
    slsa_valid: bool = Field(False)
    trivy_critical_cves: int = Field(0)
    kyverno_violations: int = Field(0)
    risk_score: float = Field(0.0)


class DeploymentValidationResponse(BaseModel):
    approved: bool
    gate_results: List[dict]
    blockers: List[str]
    warnings: List[str]


@deployment_validator_router.post("/validate", response_model=DeploymentValidationResponse)
async def validate_deployment(req: DeploymentValidationRequest):
    """Validate a deployment against security gates before rollout."""
    logger.info("deployment_validation_started", service=req.service)

    gates = []
    blockers = []
    warnings = []

    # Gate 1: Image signature
    sig_pass = req.cosign_verified
    gates.append({"gate": "Image Signature (Cosign)", "status": "PASS" if sig_pass else "BLOCK"})
    if not sig_pass:
        blockers.append("Image is not signed with Cosign")

    # Gate 2: SBOM
    sbom_pass = req.sbom_present
    gates.append({"gate": "SBOM Attestation", "status": "PASS" if sbom_pass else "BLOCK"})
    if not sbom_pass:
        blockers.append("No SBOM attestation found")

    # Gate 3: SLSA Provenance
    slsa_pass = req.slsa_valid
    gates.append({"gate": "SLSA Provenance", "status": "PASS" if slsa_pass else "BLOCK"})
    if not slsa_pass:
        blockers.append("SLSA provenance validation failed")

    # Gate 4: Critical CVEs
    cve_pass = req.trivy_critical_cves == 0
    gates.append({"gate": "Critical CVEs", "status": "PASS" if cve_pass else "BLOCK"})
    if not cve_pass:
        blockers.append(f"{req.trivy_critical_cves} critical CVEs found — patch before deployment")

    # Gate 5: Kyverno compliance
    kyv_pass = req.kyverno_violations == 0
    gates.append({"gate": "Kyverno Policy Compliance", "status": "PASS" if kyv_pass else "WARNING"})
    if not kyv_pass:
        warnings.append(f"{req.kyverno_violations} Kyverno policy violations")

    # Gate 6: Risk score
    risk_pass = req.risk_score < 50
    gates.append({"gate": "AI Risk Score", "status": "PASS" if risk_pass else "WARNING"})
    if not risk_pass:
        warnings.append(f"Risk score {req.risk_score}/100 exceeds threshold")

    approved = len(blockers) == 0
    return DeploymentValidationResponse(
        approved=approved, gate_results=gates,
        blockers=blockers, warnings=warnings,
    )
