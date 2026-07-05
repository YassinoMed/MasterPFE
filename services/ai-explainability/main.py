import logging
from typing import Dict, Any, List, Optional
from fastapi import FastAPI
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-explainability")

app = FastAPI(
    title="AI Explainability Service",
    description="Explainability and reporting service for AI-Native DevSecOps decisions.",
    version="0.1.0"
)

class ExplanationRequest(BaseModel):
    session_id: str
    query_log: str
    verdict: str
    consensus_score: float
    votes_detail: Dict[str, Dict[str, Any]]
    mitre_techniques: List[str] = Field(default_factory=list)
    sigma_rules: List[str] = Field(default_factory=list)
    cves: List[str] = Field(default_factory=list)
    remediation: str

class ExplanationResponse(BaseModel):
    markdown_report: str
    html_report: str

@app.post("/api/v1/explain", response_model=ExplanationResponse)
def explain_decision(payload: ExplanationRequest):
    """
    Generates structured explainability reports (Markdown and HTML) for SIEM consensus decisions.
    """
    logger.info(f"Generating explanation report for session {payload.session_id}...")
    
    # 1. Build Markdown report
    md = f"""# Rapport d'Explicabilité de Décision Sécurité (XAI)
**ID Session** : `{payload.session_id}`
**Verdict Final** : **{payload.verdict}**
**Score de Consensus** : `{payload.consensus_score}%`

---

## 1. Description du Log Analysé
```
{payload.query_log}
```

## 2. Délibération et Vote du Conseil Multi-Master
Les coefficients et verdicts détaillés de chaque membre du conseil de sécurité sont présentés ci-dessous :

| Nom du Master | Verdict Émis | Confiance Déclarée |
| :--- | :---: | :---: |
"""
    
    for agent, vote in payload.votes_detail.items():
        verdict = vote.get("verdict", "N/A")
        confidence = vote.get("confiance", vote.get("confidence", 0.0))
        md += f"| `{agent}` | **{verdict}** | `{confidence}%` |\n"
        
    md += f"""
## 3. Cartographie MITRE ATT&CK & Signatures
* **Techniques MITRE ATT&CK détectées** : {', '.join([f'`{t}`' for t in payload.mitre_techniques]) if payload.mitre_techniques else 'Aucune'}
* **Règles Sigma applicables** : {', '.join([f'`{r}`' for r in payload.sigma_rules]) if payload.sigma_rules else 'Aucune'}
* **Vulnérabilités CVE associées** : {', '.join([f'`{c}`' for c in payload.cves]) if payload.cves else 'Aucune'}

## 4. Plan de Remédiation Préconisé
{payload.remediation}

---
*Rapport généré automatiquement par l'Explainability Engine (AI Governance Layer).*
"""

    # 2. Build HTML report
    html = f"""<div style="font-family: sans-serif; padding: 20px; background-color: #0d1117; color: #c9d1d9; border-radius: 8px;">
    <h1 style="color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 8px;">Rapport d'Explicabilité (XAI)</h1>
    <p><strong>Session ID :</strong> <code>{payload.session_id}</code></p>
    <p><strong>Verdict Final :</strong> <span style="color: #ff7b72; font-weight: bold;">{payload.verdict}</span></p>
    <p><strong>Score de Consensus :</strong> <code>{payload.consensus_score}%</code></p>
    
    <h3 style="color: #58a6ff;">1. Log d'Événement</h3>
    <pre style="background-color: #161b22; padding: 10px; border-radius: 6px; border: 1px solid #30363d; overflow-x: auto;">{payload.query_log}</pre>
    
    <h3 style="color: #58a6ff;">2. Détails des Votes</h3>
    <table style="width: 100%; border-collapse: collapse; margin-bottom: 15px;">
        <thead>
            <tr style="border-bottom: 2px solid #30363d; text-align: left;">
                <th style="padding: 8px;">Agent Master</th>
                <th style="padding: 8px;">Verdict</th>
                <th style="padding: 8px;">Confiance</th>
            </tr>
        </thead>
        <tbody>
    """
    
    for agent, vote in payload.votes_detail.items():
        verdict = vote.get("verdict", "N/A")
        confidence = vote.get("confiance", vote.get("confidence", 0.0))
        html += f"""
            <tr style="border-bottom: 1px solid #21262d;">
                <td style="padding: 8px;"><code>{agent}</code></td>
                <td style="padding: 8px; font-weight: bold;">{verdict}</td>
                <td style="padding: 8px;"><code>{confidence}%</code></td>
            </tr>
        """
        
    html += f"""
        </tbody>
    </table>
    
    <h3 style="color: #58a6ff;">3. Corrélations de Menace</h3>
    <ul>
        <li><strong>Techniques MITRE ATT&CK :</strong> {', '.join([f'<code>{t}</code>' for t in payload.mitre_techniques]) if payload.mitre_techniques else 'Aucune'}</li>
        <li><strong>Règles Sigma :</strong> {', '.join([f'<code>{r}</code>' for r in payload.sigma_rules]) if payload.sigma_rules else 'Aucune'}</li>
        <li><strong>Vulnérabilités CVE :</strong> {', '.join([f'<code>{c}</code>' for c in payload.cves]) if payload.cves else 'Aucune'}</li>
    </ul>
    
    <h3 style="color: #58a6ff;">4. Plan d'Action</h3>
    <div style="background-color: #161b22; padding: 12px; border-radius: 6px; border-left: 4px solid #ff7b72;">
        {payload.remediation}
    </div>
</div>
"""

    return ExplanationResponse(
        markdown_report=md,
        html_report=html
    )

@app.get("/healthz")
def health():
    return {"status": "ok", "service": "ai-explainability"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8094)
