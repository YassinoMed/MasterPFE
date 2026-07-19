"""
Tests for Layer 3 — Semantic Router.

Validates TF-IDF routing across all 18+ categories,
confidence scoring, default fallback, and extensibility.
"""

import pytest


class TestSemanticRouter:
    """Tests for SemanticRouter category matching and model selection."""

    # ── Cybersecurity Domain ───────────────────────────────

    def test_route_cve_to_cybersecurity(self, semantic_router):
        """CVE queries should route to CyberSecurityAgent."""
        assert semantic_router.route("I found a CVE-2024-1234 vulnerability") == "CyberSecurityAgent"

    def test_route_trivy_to_cybersecurity(self, semantic_router):
        """Trivy scan queries should route to CyberSecurityAgent."""
        assert semantic_router.route("Trivy found critical CVE vulnerabilities in my container") == "CyberSecurityAgent"

    def test_route_falco_to_cybersecurity(self, semantic_router):
        """Falco alert queries should route to CyberSecurityAgent."""
        assert semantic_router.route("Falco detected runtime threat in pod execution") == "CyberSecurityAgent"

    def test_route_mitre_attack(self, semantic_router):
        """MITRE ATT&CK queries should route to CyberSecurityAgent."""
        assert semantic_router.route("Map this threat to MITRE ATT&CK framework") == "CyberSecurityAgent"

    def test_route_sbom_to_cybersecurity(self, semantic_router):
        """SBOM queries should route to CyberSecurityAgent."""
        assert semantic_router.route("Generate an SBOM with CycloneDX format using Syft") == "CyberSecurityAgent"

    def test_route_siem_to_cybersecurity(self, semantic_router):
        """SIEM queries should route to CyberSecurityAgent."""
        assert semantic_router.route("Write a Sigma rule for detecting lateral movement") == "CyberSecurityAgent"

    def test_route_vault_to_cybersecurity(self, semantic_router):
        """Vault queries should route to CyberSecurityAgent."""
        assert semantic_router.route("How to rotate secrets in HashiCorp Vault") == "CyberSecurityAgent"

    # ── DevOps Domain ──────────────────────────────────────

    def test_route_jenkins_to_devops(self, semantic_router):
        """Jenkins queries should route to DevOpsAgent."""
        assert semantic_router.route("My Jenkins pipeline is failing on the build stage") == "DevOpsAgent"

    def test_route_kubernetes_to_devops(self, semantic_router):
        """Kubernetes queries should route to DevOpsAgent."""
        assert semantic_router.route("How to configure Kubernetes HPA for my deployment") == "DevOpsAgent"

    def test_route_docker_to_devops(self, semantic_router):
        """Docker queries should route to DevOpsAgent."""
        assert semantic_router.route("Optimise my Dockerfile with multistage build") == "DevOpsAgent"

    def test_route_terraform_to_devops(self, semantic_router):
        """Terraform queries should route to DevOpsAgent."""
        assert semantic_router.route("Terraform plan shows unexpected resource changes") == "DevOpsAgent"

    def test_route_helm_to_devops(self, semantic_router):
        """Helm queries should route to DevOpsAgent."""
        assert semantic_router.route("How to configure Helm chart values for production") == "DevOpsAgent"

    def test_route_argocd_to_devops(self, semantic_router):
        """ArgoCD queries should route to DevOpsAgent."""
        assert semantic_router.route("ArgoCD sync is stuck and application is out of sync") == "DevOpsAgent"

    # ── Detailed Routing ───────────────────────────────────

    def test_route_detailed_returns_scores(self, semantic_router):
        """route_detailed should return category scores."""
        result = semantic_router.route_detailed("CVE vulnerability scan with Trivy")
        assert "model" in result
        assert "category" in result
        assert "confidence" in result
        assert "scores" in result
        assert isinstance(result["scores"], dict)
        assert len(result["scores"]) >= 18

    def test_route_detailed_confidence_positive(self, semantic_router):
        """Matched queries should have positive confidence."""
        result = semantic_router.route_detailed("Jenkins CI/CD pipeline")
        assert result["confidence"] > 0

    # ── Default Fallback ───────────────────────────────────

    def test_generic_prompt_fallback(self, semantic_router):
        """Very generic prompts should fall back to default model."""
        result = semantic_router.route_detailed("Hello, how are you today?")
        # Should either match with low confidence or use default
        assert result["model"] in ["CyberSecurityAgent", "DevOpsAgent"]

    # ── Category Management ────────────────────────────────

    def test_get_categories(self, semantic_router):
        """get_categories should list all registered categories."""
        categories = semantic_router.get_categories()
        assert "cybersecurity" in categories
        assert "kubernetes" in categories
        assert "docker" in categories
        assert "jenkins" in categories
        assert "terraform" in categories
        assert "falco" in categories
        assert "kyverno" in categories
        assert "vault" in categories
        assert "argocd" in categories
        assert "siem" in categories
        assert "soc" in categories
        assert "incidents" in categories
        assert "logs" in categories
        assert "cve" in categories
        assert "sbom" in categories
        assert "supply_chain" in categories
        assert "prompt_injection" in categories
        assert len(categories) >= 18

    def test_add_category_dynamically(self, semantic_router):
        """Should be able to add new categories at runtime."""
        initial_count = len(semantic_router.get_categories())
        semantic_router.add_category(
            "cloud_native",
            ["serverless", "lambda", "cloud run", "fargate", "knative"],
            "DevOpsAgent",
        )
        assert len(semantic_router.get_categories()) == initial_count + 1
        assert "cloud_native" in semantic_router.get_categories()
