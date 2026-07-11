"""Tests for GitOps configuration — validates ArgoCD manifests."""
import yaml
import pytest
from pathlib import Path


ARGOCD_DIR = Path("infra/k8s/argocd")


class TestArgoCDConfiguration:
    """Validate ArgoCD GitOps configuration."""

    def test_root_app_uses_correct_project(self):
        """Root application must use securerag-hub project, not default."""
        root_app = ARGOCD_DIR / "application-root.yaml"
        assert root_app.exists(), "Root application missing"
        with open(root_app) as f:
            doc = yaml.safe_load(f)
        project = doc["spec"]["project"]
        assert project == "securerag-hub", \
            f"Root app uses project '{project}' instead of 'securerag-hub' — security breach!"

    def test_root_app_has_auto_sync(self):
        """Root application must have automated sync enabled."""
        root_app = ARGOCD_DIR / "application-root.yaml"
        with open(root_app) as f:
            doc = yaml.safe_load(f)
        sync_policy = doc["spec"].get("syncPolicy", {})
        assert "automated" in sync_policy, "Root app missing automated sync"
        assert sync_policy["automated"].get("prune") is True, "Prune not enabled"
        assert sync_policy["automated"].get("selfHeal") is True, "SelfHeal not enabled"

    def test_applicationset_environments_exist(self):
        """ApplicationSet must define all environments."""
        appset = ARGOCD_DIR / "applicationset-all.yaml"
        with open(appset) as f:
            doc = yaml.safe_load(f)
        elements = doc["spec"]["generators"][0]["list"]["elements"]
        envs = {e["env"] for e in elements}
        expected = {"dev", "demo", "recette", "staging", "production", "dr"}
        assert expected.issubset(envs), f"Missing environments: {expected - envs}"

    def test_project_has_rbac(self):
        """AppProject must have RBAC roles defined."""
        project = ARGOCD_DIR / "project.yaml"
        with open(project) as f:
            doc = yaml.safe_load(f)
        roles = doc["spec"].get("roles", [])
        assert len(roles) > 0, "Project has no RBAC roles"
        role_names = {r["name"] for r in roles}
        assert "read-only" in role_names, "No read-only role for auditors"

    def test_notifications_configured(self):
        """Notification templates and triggers must be configured."""
        notif = ARGOCD_DIR / "notifications-cm.yaml"
        with open(notif) as f:
            doc = yaml.safe_load(f)
        data = doc.get("data", {})
        assert "template.app-out-of-sync" in data, "Missing drift detection template"
        assert "trigger.on-sync-failed" in data, "Missing sync failed trigger"
        assert "trigger.on-health-degraded" in data, "Missing health degraded trigger"

    def test_projects_directory_exists(self):
        """ArgoCD projects directory should exist with multiple projects."""
        projects_dir = ARGOCD_DIR / "projects"
        assert projects_dir.exists(), "Projects directory missing"
        project_files = list(projects_dir.glob("*.yaml"))
        assert len(project_files) >= 3, f"Only {len(project_files)} projects — expected at least 3"

    def test_applicationsets_directory_exists(self):
        """ApplicationSets directory should exist."""
        appsets_dir = ARGOCD_DIR / "applicationsets"
        assert appsets_dir.exists(), "ApplicationSets directory missing"
        appset_files = list(appsets_dir.glob("*.yaml"))
        assert len(appset_files) >= 3, f"Only {len(appset_files)} applicationsets"

    def test_sync_waves_ordering(self):
        """Sync waves should follow logical dependency order."""
        appset = ARGOCD_DIR / "applicationset-all.yaml"
        with open(appset) as f:
            doc = yaml.safe_load(f)
        elements = doc["spec"]["generators"][0]["list"]["elements"]
        waves = {e["env"]: int(e["wave"]) for e in elements}

        # Dev should come before production
        assert waves.get("dev", 0) <= waves.get("production", 100), \
            "Dev wave should be before production"
        # Production should come before DR
        if "dr" in waves:
            assert waves.get("production", 0) <= waves["dr"], \
                "Production wave should be before DR"
