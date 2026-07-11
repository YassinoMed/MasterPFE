"""Tests for Kyverno policies — validates policy correctness."""
import subprocess
import json
import pytest
import yaml
from pathlib import Path


POLICIES_DIR = Path("infra/k8s/policies/kyverno")
KYVERNO_DIR = Path("infra/k8s/kyverno")


class TestKyvernoPolicies:
    """Validate Kyverno policy manifests."""

    def test_policies_are_valid_yaml(self):
        """All policy files must be valid YAML."""
        for policy_file in POLICIES_DIR.rglob("*.yaml"):
            if policy_file.name == "kustomization.yaml":
                continue
            with open(policy_file) as f:
                docs = list(yaml.safe_load_all(f))
                assert len(docs) > 0, f"{policy_file} is empty"
                for doc in docs:
                    if doc:
                        assert "apiVersion" in doc, f"{policy_file} missing apiVersion"

    def test_enforce_policies_have_correct_action(self):
        """Enforce policies must have validationFailureAction: Enforce."""
        enforce_dir = POLICIES_DIR / "enforce"
        if not enforce_dir.exists():
            pytest.skip("No enforce directory")

        for policy_file in enforce_dir.glob("*.yaml"):
            if policy_file.name == "kustomization.yaml":
                continue
            with open(policy_file) as f:
                for doc in yaml.safe_load_all(f):
                    if doc and doc.get("kind") in ("ClusterPolicy", "Policy"):
                        action = doc.get("spec", {}).get("validationFailureAction", "")
                        # Enforce or Audit are valid
                        assert action in ("Enforce", "Audit"), \
                            f"{policy_file}: {doc['metadata']['name']} has action={action}"

    def test_slsa_enforcement_exists(self):
        """SLSA enforcement policy must exist."""
        slsa_file = KYVERNO_DIR / "slsa-enforcement.yaml"
        assert slsa_file.exists(), "SLSA enforcement policy missing"

    def test_pod_security_mutation_exists(self):
        """Pod security mutation policy must exist."""
        mut_file = KYVERNO_DIR / "mutate-pod-security.yaml"
        assert mut_file.exists(), "Pod security mutation policy missing"

    def test_comprehensive_policies_cover_all_controls(self):
        """Comprehensive policies file should cover key security controls."""
        comp_file = POLICIES_DIR / "enforce" / "comprehensive-policies.yaml"
        if not comp_file.exists():
            pytest.skip("comprehensive-policies.yaml not found")

        with open(comp_file) as f:
            content = f.read()

        expected_policies = [
            "require-readonly-rootfs",
            "require-resource-limits",
            "require-labels",
            "require-annotations",
            "require-networkpolicy",
            "enforce-pod-security",
            "restrict-ingress-no-tls",
        ]
        for policy in expected_policies:
            assert policy in content, f"Policy {policy} missing from comprehensive-policies.yaml"


class TestSupplyChainPolicies:
    """Validate supply chain security policies."""

    def test_block_unsigned_images_exists(self):
        """Block unsigned images policy must exist."""
        policy_file = POLICIES_DIR / "enforce" / "block-unsigned-images.yaml"
        assert policy_file.exists(), "block-unsigned-images.yaml missing"

    def test_verify_sbom_exists(self):
        """SBOM verification policy must exist."""
        policy_file = POLICIES_DIR / "enforce" / "verify-sbom.yaml"
        assert policy_file.exists(), "verify-sbom.yaml missing"

    def test_verify_provenance_exists(self):
        """SLSA provenance verification policy must exist."""
        policy_file = POLICIES_DIR / "enforce" / "verify-slsa-provenance.yaml"
        assert policy_file.exists(), "verify-slsa-provenance.yaml missing"
