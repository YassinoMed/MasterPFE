"""Kubernetes Audit Agent — K8s manifest security analysis."""
import yaml
import structlog
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Dict, Optional

logger = structlog.get_logger()
k8s_audit_router = APIRouter()


class K8sAuditRequest(BaseModel):
    manifests: List[str] = Field(default_factory=list, description="List of YAML manifest contents")
    namespace: str = Field("securerag-hub")


class K8sFinding(BaseModel):
    resource: str
    kind: str
    severity: str
    rule: str
    description: str
    remediation: str


class K8sAuditResponse(BaseModel):
    total_resources: int
    total_findings: int
    critical: int
    high: int
    findings: List[K8sFinding]
    risk_score: float
    decision: str
    compliance_score: float


def _audit_manifest(doc: dict) -> List[K8sFinding]:
    """Audit a single Kubernetes manifest for security issues."""
    findings = []
    kind = doc.get("kind", "Unknown")
    name = doc.get("metadata", {}).get("name", "unknown")
    resource = f"{kind}/{name}"

    if kind in ("Deployment", "StatefulSet", "DaemonSet"):
        spec = doc.get("spec", {}).get("template", {}).get("spec", {})
        containers = spec.get("containers", [])

        for c in containers:
            cname = c.get("name", "unknown")
            sec = c.get("securityContext", {})

            # Check runAsNonRoot
            pod_sec = spec.get("securityContext", {})
            if not pod_sec.get("runAsNonRoot") and not sec.get("runAsNonRoot"):
                findings.append(K8sFinding(
                    resource=resource, kind=kind, severity="CRITICAL",
                    rule="KSV-012", description=f"Container {cname} may run as root",
                    remediation="Set securityContext.runAsNonRoot: true"
                ))

            # Check privilege escalation
            if sec.get("allowPrivilegeEscalation", True):
                findings.append(K8sFinding(
                    resource=resource, kind=kind, severity="HIGH",
                    rule="KSV-001", description=f"Container {cname} allows privilege escalation",
                    remediation="Set securityContext.allowPrivilegeEscalation: false"
                ))

            # Check readOnlyRootFilesystem
            if not sec.get("readOnlyRootFilesystem"):
                findings.append(K8sFinding(
                    resource=resource, kind=kind, severity="HIGH",
                    rule="KSV-014", description=f"Container {cname} has writable root filesystem",
                    remediation="Set securityContext.readOnlyRootFilesystem: true"
                ))

            # Check resource limits
            resources = c.get("resources", {})
            if not resources.get("limits"):
                findings.append(K8sFinding(
                    resource=resource, kind=kind, severity="MEDIUM",
                    rule="KSV-015", description=f"Container {cname} has no resource limits",
                    remediation="Set resources.limits for CPU and memory"
                ))

            # Check capabilities
            caps = sec.get("capabilities", {})
            if not caps.get("drop") or "ALL" not in caps.get("drop", []):
                findings.append(K8sFinding(
                    resource=resource, kind=kind, severity="HIGH",
                    rule="KSV-022", description=f"Container {cname} doesn't drop ALL capabilities",
                    remediation="Set securityContext.capabilities.drop: [ALL]"
                ))

            # Check image tag
            image = c.get("image", "")
            if ":latest" in image or (":dev" in image and "localhost" not in image):
                findings.append(K8sFinding(
                    resource=resource, kind=kind, severity="HIGH",
                    rule="KSV-030", description=f"Container {cname} uses mutable tag: {image}",
                    remediation="Pin image to SHA256 digest"
                ))

            # Check probes
            if not c.get("readinessProbe"):
                findings.append(K8sFinding(
                    resource=resource, kind=kind, severity="MEDIUM",
                    rule="KSV-020", description=f"Container {cname} has no readiness probe",
                    remediation="Add readinessProbe with httpGet or tcpSocket"
                ))
            if not c.get("livenessProbe"):
                findings.append(K8sFinding(
                    resource=resource, kind=kind, severity="MEDIUM",
                    rule="KSV-021", description=f"Container {cname} has no liveness probe",
                    remediation="Add livenessProbe with httpGet or tcpSocket"
                ))

        # Check seccompProfile
        if not spec.get("securityContext", {}).get("seccompProfile"):
            findings.append(K8sFinding(
                resource=resource, kind=kind, severity="MEDIUM",
                rule="KSV-032", description="No seccompProfile defined",
                remediation="Set securityContext.seccompProfile.type: RuntimeDefault"
            ))

        # Check labels
        labels = doc.get("metadata", {}).get("labels", {})
        if "app.kubernetes.io/name" not in labels:
            findings.append(K8sFinding(
                resource=resource, kind=kind, severity="LOW",
                rule="KSV-040", description="Missing standard label app.kubernetes.io/name",
                remediation="Add Kubernetes recommended labels"
            ))

    return findings


@k8s_audit_router.post("/analyze", response_model=K8sAuditResponse)
async def audit_manifests(req: K8sAuditRequest):
    """Audit Kubernetes manifests for security issues."""
    logger.info("k8s_audit_started", num_manifests=len(req.manifests))

    all_findings = []
    total_resources = 0

    for manifest_str in req.manifests:
        try:
            for doc in yaml.safe_load_all(manifest_str):
                if doc and isinstance(doc, dict):
                    total_resources += 1
                    all_findings.extend(_audit_manifest(doc))
        except yaml.YAMLError as e:
            logger.warning("yaml_parse_error", error=str(e))

    critical = sum(1 for f in all_findings if f.severity == "CRITICAL")
    high = sum(1 for f in all_findings if f.severity == "HIGH")

    risk_score = min(100.0, critical * 20 + high * 10 + len(all_findings) * 2)
    compliance_score = max(0, 100 - risk_score)
    decision = "BLOCK" if critical > 2 else "WARNING" if critical > 0 or high > 3 else "PASS"

    return K8sAuditResponse(
        total_resources=total_resources,
        total_findings=len(all_findings), critical=critical, high=high,
        findings=all_findings[:50], risk_score=risk_score,
        decision=decision, compliance_score=round(compliance_score, 1),
    )
