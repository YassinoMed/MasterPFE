import logging
from typing import Dict, Any, List, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-knowledge")

app = FastAPI(
    title="AI Knowledge Graph Service",
    description="Knowledge Graph service mapping security dependencies and relations.",
    version="0.1.0"
)

# In-memory graph representation
# Nodes: {"id": str, "label": str, "properties": Dict[str, Any]}
# Edges: {"source": str, "target": str, "type": str}
graph_nodes = [
    {"id": "repo_securerag", "label": "Repository", "properties": {"name": "SecureRAG-Hub", "url": "https://github.com/YassinoMed/MasterPFE"}},
    {"id": "commit_101", "label": "Commit", "properties": {"sha": "101a06d40", "author": "developer-yassine"}},
    {"id": "dev_yassine", "label": "Developer", "properties": {"name": "Yassine", "role": "DevSecOps Architect"}},
    {"id": "img_portal", "label": "DockerImage", "properties": {"name": "securerag-hub-portal-web", "tag": "latest"}},
    {"id": "sbom_portal", "label": "SBOM", "properties": {"format": "CycloneDX", "packages_count": 142}},
    {"id": "cve_2026_53539", "label": "CVE", "properties": {"id": "CVE-2026-53539", "severity": "HIGH", "description": "DoS in python-multipart"}},
    {"id": "pod_portal_1", "label": "Pod", "properties": {"name": "portal-web-86f77-2sjc", "namespace": "securerag-hub"}},
    {"id": "ns_securerag", "label": "Namespace", "properties": {"name": "securerag-hub", "security_profile": "restricted"}},
    {"id": "svc_portal", "label": "Service", "properties": {"name": "portal-web-service"}},
    {"id": "node_worker_1", "label": "Node", "properties": {"name": "kind-worker-1", "ip": "172.18.0.3"}},
    {"id": "mitre_t1190", "label": "MITRE", "properties": {"id": "T1190", "name": "Exploit Public-Facing Application"}},
    {"id": "sigma_r1", "label": "SigmaRule", "properties": {"name": "web_interactive_shell", "file": "webserver_shell.yml"}},
    {"id": "inc_982410", "label": "Incident", "properties": {"id": "evt_consensus_982410", "risk_score": 57.5}},
    {"id": "playbook_isolation", "label": "Playbook", "properties": {"name": "Quarantine Pod", "remediation_type": "NetworkPolicy"}},
]

graph_edges = [
    {"source": "dev_yassine", "target": "commit_101", "type": "AUTHORED"},
    {"source": "commit_101", "target": "repo_securerag", "type": "PUSHED_TO"},
    {"source": "commit_101", "target": "img_portal", "type": "BUILT_IMAGE"},
    {"source": "img_portal", "target": "sbom_portal", "type": "HAS_SBOM"},
    {"source": "sbom_portal", "target": "cve_2026_53539", "type": "CONTAINS_VULNERABILITY"},
    {"source": "img_portal", "target": "pod_portal_1", "type": "RUNNING_IN_POD"},
    {"source": "pod_portal_1", "target": "ns_securerag", "type": "BELONGS_TO_NAMESPACE"},
    {"source": "pod_portal_1", "target": "node_worker_1", "type": "SCHEDULED_ON"},
    {"source": "svc_portal", "target": "pod_portal_1", "type": "ROUTES_TO"},
    {"source": "cve_2026_53539", "target": "mitre_t1190", "type": "MAPPED_TO_TECHNIQUE"},
    {"source": "sigma_r1", "target": "mitre_t1190", "type": "DETECTS_TECHNIQUE"},
    {"source": "inc_982410", "target": "pod_portal_1", "type": "TARGETED_WORKLOAD"},
    {"source": "inc_982410", "target": "cve_2026_53539", "type": "EXPLOITED_VULNERABILITY"},
    {"source": "playbook_isolation", "target": "inc_982410", "type": "REMEDIATED_INCIDENT"},
]

class QueryRequest(BaseModel):
    start_node_id: str
    relation_type: Optional[str] = None

class QueryResponse(BaseModel):
    paths: List[Dict[str, Any]]

@app.get("/api/v1/knowledge/graph")
def get_graph():
    """
    Returns the complete knowledge graph nodes and edges.
    """
    logger.info("Retrieving complete security knowledge graph...")
    return {
        "nodes": graph_nodes,
        "edges": graph_edges
    }

@app.post("/api/v1/knowledge/query", response_model=QueryResponse)
def query_relationships(payload: QueryRequest):
    """
    Finds direct relationships in the security graph.
    """
    logger.info(f"Querying graph relationships starting at '{payload.start_node_id}'...")
    paths = []
    
    for edge in graph_edges:
        if edge["source"] == payload.start_node_id:
            if payload.relation_type is None or edge["type"] == payload.relation_type:
                paths.append(edge)
                
    return QueryResponse(paths=paths)

@app.get("/healthz")
def health():
    return {"status": "ok", "service": "ai-knowledge"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8096)
