import os
import httpx
import uuid
import logging
from typing import Dict, Any, List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-orchestrator")

app = FastAPI(
    title="AI Orchestrator Service",
    description="Central orchestration layer of the AI Governance Layer.",
    version="0.1.0"
)

# Service URLs from environment (for internal K8s communication or localhost fallback)
RISK_ENGINE_URL = os.getenv("RISK_ENGINE_URL", "http://localhost:8092")
TRUST_ENGINE_URL = os.getenv("TRUST_ENGINE_URL", "http://localhost:8093")
EXPLAINABILITY_URL = os.getenv("EXPLAINABILITY_URL", "http://localhost:8094")
MEMORY_URL = os.getenv("MEMORY_URL", "http://localhost:8095")
KNOWLEDGE_URL = os.getenv("KNOWLEDGE_URL", "http://localhost:8096")
FEEDBACK_URL = os.getenv("FEEDBACK_URL", "http://localhost:8097")
METRICS_URL = os.getenv("METRICS_URL", "http://localhost:8098")

class PlanRequest(BaseModel):
    requirements: str = Field(..., example="Deploy a public portal-web application connecting to postgres-auth database.")

class PlanResponse(BaseModel):
    plan_id: str
    proposed_architecture: str
    stride_threat_model: str
    mermaid_diagram: str
    architecture_risks: List[str]
    countermeasures: List[str]

# --- AI Planning Agent ---
def generate_stride_threat_model(requirements: str) -> Dict[str, Any]:
    """
    Generates a secure architecture, STRIDE threat model, Mermaid diagrams,
    risks, and countermeasures using heuristics or model routing.
    """
    req_lower = requirements.lower()
    proposed_arch = "Architecture Zero-Trust multi-tiers avec microservices isolés."
    
    risks = []
    countermeasures = []
    
    # Analyze requirements for threats
    if "public" in req_lower or "portal" in req_lower:
        risks.append("Exposition publique de l'application (Port d'entrée potentiel pour attaques DDoS/OWASP Top 10).")
        countermeasures.append("Déployer un Ingress Controller avec WAF (Web Application Firewall) et restriction de débit (Rate Limiting).")
        
    if "postgres" in req_lower or "database" in req_lower or "db" in req_lower:
        risks.append("Accès direct non autorisé à la base de données PostgreSQL ou fuite de secrets d'authentification.")
        countermeasures.append("Appliquer une NetworkPolicy Cilium restrictive autorisant uniquement les pods habilités sur le port 5432.")
        countermeasures.append("Stocker les identifiants dans HashiCorp Vault et les injecter via External Secrets Operator.")
        
    if "root" in req_lower or "privileged" in req_lower:
        risks.append("Exécution de conteneurs avec privilèges élevés (Contournement de la sécurité de l'hôte - Container Escape).")
        countermeasures.append("Appliquer le profil PodSecurity Standard/Restricted à l'admission avec Kyverno.")
        
    # Default fallback risks if empty
    if not risks:
        risks.append("Absence de validation d'admission des manifests de déploiement Kubernetes.")
        countermeasures.append("Enforcer les règles d'admission Kyverno et les scans statiques Trivy/Semgrep dans le pipeline.")

    # Stride threat model document
    stride_doc = f"""# Threat Model STRIDE pour l'exigence : "{requirements}"

## 1. Analyse des Menaces par Catégorie
| Catégorie STRIDE | Menace Identifiée | Niveau de Risque | Contre-mesures Proposées |
| :--- | :--- | :--- | :--- |
| **Spoofing (Usurpation)** | Usurpation de l'identité du client API. | Moyen | Authentification mTLS renforcée par Istio et jetons JWT signés. |
| **Tampering (Altération)** | Modification des manifests YAML en transit ou altération d'images Docker. | Élevé | Signature des images avec Cosign et vérification de provenance SLSA. |
| **Repudiation (Répudiation)** | Actions malveillantes non auditables dans le cluster. | Faible | Centralisation des logs d'audit Kubernetes dans Loki/Wazuh. |
| **Information Disclosure** | Fuite de secrets de connexion DB dans les variables d'environnement. | Élevé | Intégration de Vault + montage de secrets en mémoire (tmpfs). |
| **Denial of Service** | DoS sur le service frontal. | Moyen | Configuration de ResourceQuotas K8s et autoscaling HPA. |
| **Elevation of Privilege** | Compromission d'un pod avec élévation des privilèges système. | Élevé | Restriction des runtime system calls via eBPF/Tetragon et Kyverno restricted PSA. |
"""

    mermaid_diag = """graph TD
    User([Utilisateur externe]) -->|HTTPS / Port 443| Ingress[Ingress Controller + WAF]
    Ingress -->|mTLS / Route autorisée| App[Pod applicatif / securerag-hub]
    App -->|Port 5432 / NetworkPolicy Deny-All| DB[(Database postgres-auth)]
    style Ingress fill:#2d3748,stroke:#3182ce,stroke-width:2px,color:#fff
    style App fill:#1a365d,stroke:#3182ce,stroke-width:2px,color:#fff
    style DB fill:#2c5282,stroke:#3182ce,stroke-width:2px,color:#fff
"""

    return {
        "proposed_architecture": proposed_arch,
        "stride_threat_model": stride_doc,
        "mermaid_diagram": mermaid_diag,
        "architecture_risks": risks,
        "countermeasures": countermeasures
    }

@app.post("/api/v1/plan", response_model=PlanResponse)
async def create_security_plan(payload: PlanRequest):
    """
    FastAPI endpoint for the AI Planning Agent.
    """
    logger.info(f"AI Planning Agent triggered for requirement: '{payload.requirements}'")
    try:
        plan_data = generate_stride_threat_model(payload.requirements)
        return PlanResponse(
            plan_id=str(uuid.uuid4()),
            proposed_architecture=plan_data["proposed_architecture"],
            stride_threat_model=plan_data["stride_threat_model"],
            mermaid_diagram=plan_data["mermaid_diagram"],
            architecture_risks=plan_data["architecture_risks"],
            countermeasures=plan_data["countermeasures"]
        )
    except Exception as e:
        logger.error(f"Planning error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/healthz")
async def health():
    return {"status": "ok", "service": "ai-orchestrator"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8091)
