import yaml
import networkx as nx
from typing import Dict, List, Any

class DependencyGraph:
    def __init__(self, config_path: str = "config.yaml"):
        self.graph = nx.DiGraph()
        self.load_config(config_path)

    def load_config(self, config_path: str):
        with open(config_path, 'r') as file:
            data = yaml.safe_load(file)

        # Add nodes
        for node in data.get("nodes", []):
            self.graph.add_node(node["id"], label=node.get("label", node["id"]), group=node.get("group", "default"))

        # Add edges (Directed: A -> B means A depends on B)
        # So if A fails, B is NOT affected. If B fails, A IS affected.
        # Blast Radius of B = all ancestors of B (nodes that depend on B)
        # Impact Analysis of A = all descendants of A (nodes that A depends on)
        for edge in data.get("edges", []):
            self.graph.add_edge(edge["from"], edge["to"], type=edge.get("type", "depends-on"))

    def get_full_graph(self) -> Dict[str, Any]:
        nodes = [{"id": n, **self.graph.nodes[n]} for n in self.graph.nodes()]
        edges = [{"from": u, "to": v, **self.graph.edges[u, v]} for u, v in self.graph.edges()]
        return {"nodes": nodes, "edges": edges}

    def get_blast_radius(self, node_id: str) -> List[str]:
        """
        If node_id fails, what else fails?
        Everything that depends on node_id (ancestors in the DAG).
        """
        if node_id not in self.graph:
            return []
        # In a directed graph A->B (A depends on B), ancestors of B are nodes that have a path to B.
        affected = nx.ancestors(self.graph, node_id)
        return list(affected)

    def get_impact_analysis(self, node_id: str) -> List[str]:
        """
        If we want to know what node_id depends on.
        Everything that node_id depends on (descendants in the DAG).
        """
        if node_id not in self.graph:
            return []
        # descendants of A are nodes reachable from A
        dependencies = nx.descendants(self.graph, node_id)
        return list(dependencies)
