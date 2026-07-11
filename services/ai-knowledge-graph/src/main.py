"""
AI Knowledge Graph — Security relationship graph service.

Builds a graph of relationships between: microservices, pods, containers,
images, SBOMs, CVEs, secrets, policies, namespaces, services, dependencies.
Enables AI-powered security queries like:
  - "Which pods are affected by CVE-2024-XXXX?"
  - "What is the blast radius if this service is compromised?"
  - "Which secrets are accessible from this namespace?"
"""

import structlog
import networkx as nx
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Dict, List, Optional, Any
from prometheus_fastapi_instrumentator import Instrumentator

logger = structlog.get_logger()

app = FastAPI(
    title="AI Knowledge Graph Service",
    description="Security knowledge graph for AI-powered security queries.",
    version="1.0.0",
)

Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# Global graph instance
graph = nx.DiGraph()


# --- Models ---

class NodeCreate(BaseModel):
    node_id: str = Field(..., example="pod/securerag-hub/portal-web-abc123")
    node_type: str = Field(..., example="pod")
    properties: Dict[str, Any] = Field(default_factory=dict)


class EdgeCreate(BaseModel):
    source: str = Field(..., example="pod/portal-web-abc123")
    target: str = Field(..., example="image/securerag-hub-portal-web:v1")
    relationship: str = Field(..., example="USES_IMAGE")
    properties: Dict[str, Any] = Field(default_factory=dict)


class QueryRequest(BaseModel):
    question: str = Field(..., example="Which pods are affected by CVE-2024-1234?")
    node_id: Optional[str] = Field(None)
    node_type: Optional[str] = Field(None)
    max_depth: int = Field(3, ge=1, le=10)


class QueryResponse(BaseModel):
    question: str
    answer: str
    nodes_found: int
    paths: List[List[str]]
    metadata: Dict[str, Any]


class GraphStats(BaseModel):
    total_nodes: int
    total_edges: int
    node_types: Dict[str, int]
    relationship_types: Dict[str, int]


# --- API Routes ---

@app.post("/api/v1/graph/nodes")
async def add_node(node: NodeCreate):
    """Add a node to the knowledge graph."""
    graph.add_node(node.node_id, node_type=node.node_type, **node.properties)
    logger.info("node_added", node_id=node.node_id, node_type=node.node_type)
    return {"status": "created", "node_id": node.node_id}


@app.post("/api/v1/graph/edges")
async def add_edge(edge: EdgeCreate):
    """Add an edge (relationship) to the knowledge graph."""
    if edge.source not in graph:
        graph.add_node(edge.source, node_type="unknown")
    if edge.target not in graph:
        graph.add_node(edge.target, node_type="unknown")
    graph.add_edge(edge.source, edge.target, relationship=edge.relationship, **edge.properties)
    logger.info("edge_added", source=edge.source, target=edge.target, rel=edge.relationship)
    return {"status": "created", "source": edge.source, "target": edge.target}


@app.post("/api/v1/graph/bulk")
async def bulk_import(nodes: List[NodeCreate] = [], edges: List[EdgeCreate] = []):
    """Bulk import nodes and edges."""
    for n in nodes:
        graph.add_node(n.node_id, node_type=n.node_type, **n.properties)
    for e in edges:
        if e.source not in graph:
            graph.add_node(e.source, node_type="unknown")
        if e.target not in graph:
            graph.add_node(e.target, node_type="unknown")
        graph.add_edge(e.source, e.target, relationship=e.relationship, **e.properties)
    return {"nodes_added": len(nodes), "edges_added": len(edges)}


@app.get("/api/v1/graph/stats", response_model=GraphStats)
async def get_stats():
    """Get graph statistics."""
    node_types = {}
    for _, data in graph.nodes(data=True):
        nt = data.get("node_type", "unknown")
        node_types[nt] = node_types.get(nt, 0) + 1

    rel_types = {}
    for _, _, data in graph.edges(data=True):
        rt = data.get("relationship", "unknown")
        rel_types[rt] = rel_types.get(rt, 0) + 1

    return GraphStats(
        total_nodes=graph.number_of_nodes(),
        total_edges=graph.number_of_edges(),
        node_types=node_types,
        relationship_types=rel_types,
    )


@app.post("/api/v1/graph/query", response_model=QueryResponse)
async def query_graph(req: QueryRequest):
    """Query the knowledge graph with a security question."""
    logger.info("graph_query", question=req.question)

    question_lower = req.question.lower()
    nodes_found = []
    paths = []
    answer = ""

    # CVE impact query
    if "cve" in question_lower:
        import re
        cve_match = re.search(r'cve-\d{4}-\d+', question_lower, re.IGNORECASE)
        if cve_match:
            cve_id = cve_match.group(0).upper()
            # Find all nodes connected to this CVE
            if cve_id in graph:
                affected = list(nx.ancestors(graph, cve_id)) + list(nx.descendants(graph, cve_id))
                pods = [n for n in affected if graph.nodes[n].get("node_type") == "pod"]
                images = [n for n in affected if graph.nodes[n].get("node_type") == "image"]
                answer = f"{cve_id} affects {len(pods)} pods and {len(images)} images."
                nodes_found = affected[:20]

    # Blast radius query
    elif "blast radius" in question_lower or "impact" in question_lower:
        if req.node_id and req.node_id in graph:
            descendants = list(nx.descendants(graph, req.node_id))
            ancestors = list(nx.ancestors(graph, req.node_id))
            all_affected = set(descendants + ancestors)
            answer = f"Blast radius for {req.node_id}: {len(all_affected)} connected resources."
            nodes_found = list(all_affected)[:20]
            # Find shortest paths
            for target in list(all_affected)[:5]:
                try:
                    path = nx.shortest_path(graph, req.node_id, target)
                    paths.append(path)
                except nx.NetworkXNoPath:
                    pass

    # Secret exposure query
    elif "secret" in question_lower:
        secret_nodes = [n for n, d in graph.nodes(data=True) if d.get("node_type") == "secret"]
        pods_with_secrets = []
        for secret in secret_nodes:
            connected = list(graph.predecessors(secret)) + list(graph.successors(secret))
            pods_with_secrets.extend(connected)
        answer = f"Found {len(secret_nodes)} secrets accessible from {len(set(pods_with_secrets))} resources."
        nodes_found = secret_nodes[:20]

    # Policy compliance query
    elif "policy" in question_lower or "compliance" in question_lower:
        policy_nodes = [n for n, d in graph.nodes(data=True) if d.get("node_type") == "policy"]
        violated = [n for n in policy_nodes if graph.nodes[n].get("status") == "violated"]
        answer = f"{len(policy_nodes)} policies tracked, {len(violated)} currently violated."
        nodes_found = violated[:20]

    # Generic node lookup
    elif req.node_type:
        matching = [n for n, d in graph.nodes(data=True) if d.get("node_type") == req.node_type]
        answer = f"Found {len(matching)} nodes of type '{req.node_type}'."
        nodes_found = matching[:20]

    else:
        answer = f"Graph has {graph.number_of_nodes()} nodes and {graph.number_of_edges()} edges."

    return QueryResponse(
        question=req.question,
        answer=answer,
        nodes_found=len(nodes_found),
        paths=paths[:10],
        metadata={
            "graph_size": graph.number_of_nodes(),
            "query_timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )


@app.get("/api/v1/graph/neighbors/{node_id:path}")
async def get_neighbors(node_id: str, depth: int = 1):
    """Get neighbors of a node up to a given depth."""
    if node_id not in graph:
        raise HTTPException(404, f"Node {node_id} not found")

    neighbors = set()
    current = {node_id}
    for _ in range(depth):
        next_level = set()
        for n in current:
            next_level.update(graph.successors(n))
            next_level.update(graph.predecessors(n))
        neighbors.update(next_level)
        current = next_level

    return {
        "node_id": node_id,
        "depth": depth,
        "neighbors_count": len(neighbors),
        "neighbors": [
            {"id": n, "type": graph.nodes[n].get("node_type", "unknown")}
            for n in list(neighbors)[:50]
        ]
    }


@app.get("/healthz")
async def healthz():
    return {"status": "ok", "service": "ai-knowledge-graph", "nodes": graph.number_of_nodes()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8110)
