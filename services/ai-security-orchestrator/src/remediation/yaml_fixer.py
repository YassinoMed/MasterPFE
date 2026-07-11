"""
YAML Fixer — Automated fixes for Kubernetes manifests and Helm values.
"""

import yaml
import structlog

logger = structlog.get_logger()


class YamlFixer:
    """Provides automated patches for security findings in K8s YAML files."""

    def fix_manifest(self, yaml_content: str) -> str:
        """Parses and fixes security vulnerabilities in a YAML manifest."""
        try:
            docs = list(yaml.safe_load_all(yaml_content))
            fixed_docs = []

            for doc in docs:
                if not doc or not isinstance(doc, dict):
                    continue

                kind = doc.get("kind", "")
                if kind in ("Deployment", "StatefulSet", "DaemonSet"):
                    doc = self._fix_workload(doc)
                fixed_docs.append(doc)

            if len(fixed_docs) == 1:
                return yaml.dump(fixed_docs[0], sort_keys=False)
            return yaml.dump_all(fixed_docs, sort_keys=False)
        except Exception as e:
            logger.error("yaml_fix_failed", error=str(e))
            return yaml_content

    def _fix_workload(self, doc: dict) -> dict:
        """Apply security settings to deployment-like workloads."""
        # 1. Ensure securityContext in Pod spec
        spec = doc.setdefault("spec", {})
        template = spec.setdefault("template", {})
        pod_spec = template.setdefault("spec", {})
        pod_sec = pod_spec.setdefault("securityContext", {})

        # Enforce runAsNonRoot
        if "runAsNonRoot" not in pod_sec:
            pod_sec["runAsNonRoot"] = True
        if "seccompProfile" not in pod_sec:
            pod_sec["seccompProfile"] = {"type": "RuntimeDefault"}

        # 2. Enforce container settings
        containers = pod_spec.setdefault("containers", [])
        for c in containers:
            sec = c.setdefault("securityContext", {})
            sec["allowPrivilegeEscalation"] = False
            sec["readOnlyRootFilesystem"] = True

            # Ensure capabilities are dropped
            caps = sec.setdefault("capabilities", {})
            caps["drop"] = ["ALL"]

            # Ensure resource requests/limits exist
            res = c.setdefault("resources", {})
            req = res.setdefault("requests", {})
            lim = res.setdefault("limits", {})

            if "cpu" not in req: req["cpu"] = "100m"
            if "memory" not in req: req["memory"] = "128Mi"
            if "cpu" not in lim: lim["cpu"] = "500m"
            if "memory" not in lim: lim["memory"] = "256Mi"

        return doc
