from kubernetes import client, config
import logging

logger = logging.getLogger(__name__)

def get_k8s_client():
    try:
        config.load_incluster_config()
    except config.config_exception.ConfigException:
        logger.warning("Not running inside cluster, falling back to kube-config.")
        try:
            config.load_kube_config()
        except Exception as e:
            logger.error(f"Failed to load kube config: {e}")
            return None
    return client.CustomObjectsApi()

def collect_kubernetes_data():
    api = get_k8s_client()
    data = {
        "kyverno_policies": [],
        "trivy_vulnerabilities": []
    }
    if not api:
        return data
        
    try:
        # Collect Kyverno PolicyReports
        reports = api.list_cluster_custom_object(
            group="wgpolicyk8s.io",
            version="v1alpha2",
            plural="clusterpolicyreports"
        )
        data["kyverno_policies"] = reports.get("items", [])
    except Exception as e:
        logger.error(f"Failed to collect Kyverno reports: {e}")

    try:
        # Collect Trivy VulnerabilityReports
        reports = api.list_cluster_custom_object(
            group="aquasecurity.github.io",
            version="v1alpha1",
            plural="vulnerabilityreports"
        )
        data["trivy_vulnerabilities"] = reports.get("items", [])
    except Exception as e:
        logger.error(f"Failed to collect Trivy reports: {e}")

    return data
