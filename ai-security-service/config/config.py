"""
Centralized configuration for AI Security Service.

Loads settings from environment variables with sensible defaults.
All model paths, thresholds, and feature flags live here.
"""

import os
from dataclasses import dataclass, field
from typing import Dict, List
from functools import lru_cache


@dataclass(frozen=True)
class Settings:
    """Immutable application settings loaded from environment."""

    # ── Service ────────────────────────────────────────────────
    SERVICE_NAME: str = "ai-security-service"
    VERSION: str = "2.0.0"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "production")
    HOST: str = os.getenv("SERVICE_HOST", "0.0.0.0")
    PORT: int = int(os.getenv("SERVICE_PORT", "8000"))
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")

    # ── Layer 1: Prompt Injection ──────────────────────────────
    PI_MODEL_NAME: str = os.getenv(
        "PI_MODEL_NAME",
        "protectai/deberta-v3-small-prompt-injection-v2"
    )
    PI_MAX_LENGTH: int = int(os.getenv("PI_MAX_LENGTH", "512"))
    PI_SUSPICIOUS_THRESHOLD: float = float(os.getenv("PI_SUSPICIOUS_THRESHOLD", "0.5"))
    PI_MALICIOUS_THRESHOLD: float = float(os.getenv("PI_MALICIOUS_THRESHOLD", "0.8"))

    # ── Layer 2: Jailbreak Detection ───────────────────────────
    JB_MODEL_NAME: str = os.getenv(
        "JB_MODEL_NAME",
        "llm-semantic-router/mmbert32k-jailbreak-detector-merged"
    )
    JB_MAX_LENGTH: int = int(os.getenv("JB_MAX_LENGTH", "512"))
    JB_REVIEW_THRESHOLD: float = float(os.getenv("JB_REVIEW_THRESHOLD", "0.5"))
    JB_DENY_THRESHOLD: float = float(os.getenv("JB_DENY_THRESHOLD", "0.8"))

    # ── Layer 3: Semantic Router ───────────────────────────────
    ROUTER_DEFAULT_MODEL: str = os.getenv("ROUTER_DEFAULT_MODEL", "DevOpsAgent")
    ROUTER_CONFIDENCE_THRESHOLD: float = float(os.getenv("ROUTER_CONFIDENCE_THRESHOLD", "0.15"))

    # ── Layer 4a: CyberSecurity Agent (BaronLLM GGUF) ─────────
    CYBER_MODEL_PATH: str = os.getenv(
        "CYBER_MODEL_PATH",
        "AlicanKiraz0/Cybersecurity-BaronLLM_Offensive_Security_LLM_Q6_K_GGUF"
    )
    CYBER_CTX_SIZE: int = int(os.getenv("CYBER_CTX_SIZE", "2048"))
    CYBER_MAX_TOKENS: int = int(os.getenv("CYBER_MAX_TOKENS", "512"))
    CYBER_THREADS: int = int(os.getenv("CYBER_THREADS", "4"))
    CYBER_GPU_LAYERS: int = int(os.getenv("CYBER_GPU_LAYERS", "0"))

    # ── Layer 4b: DevOps & Pipeline Log Analysis LLM Stack ────
    DEVOPS_SENSEI_MODEL: str = os.getenv(
        "DEVOPS_SENSEI_MODEL",
        "andrebassi/devops-sensei-llama3.2-1b-merged"
    )
    DEVOPS_ULTRA_MODEL: str = os.getenv(
        "DEVOPS_ULTRA_MODEL",
        "Rapnss/DevOps-Ultra-125M"
    )
    DEVOPS_NOTES_MODEL: str = os.getenv(
        "DEVOPS_NOTES_MODEL",
        "nadtoka/llama-3.2-devops-notes-model"
    )
    DEVOPS_MAX_TOKENS: int = int(os.getenv("DEVOPS_MAX_TOKENS", "256"))

    # ── Model Cache ────────────────────────────────────────────
    MODEL_CACHE_DIR: str = os.getenv("MODEL_CACHE_DIR", "/app/model-cache")
    HF_HOME: str = os.getenv("HF_HOME", "/app/model-cache/huggingface")

    # ── Guardrails ─────────────────────────────────────────────
    GUARDRAILS_ENABLED: bool = os.getenv("GUARDRAILS_ENABLED", "true").lower() == "true"

    # ── Rate Limiting ──────────────────────────────────────────
    RATE_LIMIT_PER_MINUTE: int = int(os.getenv("RATE_LIMIT_PER_MINUTE", "60"))

    # ── Observability ──────────────────────────────────────────
    LOKI_ENABLED: bool = os.getenv("LOKI_ENABLED", "true").lower() == "true"
    PROMETHEUS_ENABLED: bool = os.getenv("PROMETHEUS_ENABLED", "true").lower() == "true"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Singleton factory for application settings."""
    return Settings()


# ── Routing Categories Definition ──────────────────────────────
# Each category maps to keywords that the SemanticRouter uses for TF-IDF matching.
# Easily extensible: add a new category + keywords here.
ROUTING_CATEGORIES: Dict[str, List[str]] = {
    "cybersecurity": [
        "cve", "vulnerability", "exploit", "malware", "ransomware", "attack",
        "threat", "intrusion", "breach", "incident response", "zero day",
        "penetration test", "pentest", "security audit", "threat intelligence",
        "indicator of compromise", "ioc", "adversary", "apt", "phishing",
    ],
    "devsecops": [
        "devsecops", "shift left", "security pipeline", "sast", "dast", "iast",
        "rasp", "code scanning", "secret scanning", "dependency check",
        "software composition analysis", "sca", "security gate", "quality gate",
    ],
    "kubernetes": [
        "kubernetes", "k8s", "pod", "deployment", "service", "ingress",
        "namespace", "configmap", "secret", "daemonset", "statefulset",
        "replicaset", "hpa", "pdb", "network policy", "rbac", "admission",
        "kubelet", "etcd", "control plane", "node", "cluster",
    ],
    "docker": [
        "docker", "container", "dockerfile", "image", "registry", "layer",
        "multistage", "buildkit", "compose", "docker-compose", "containerd",
        "cri-o", "oci", "container runtime", "distroless",
    ],
    "jenkins": [
        "jenkins", "jenkinsfile", "pipeline", "groovy", "shared library",
        "agent", "node", "stage", "build", "blue ocean", "multibranch",
        "jenkins plugin", "credentials",
    ],
    "terraform": [
        "terraform", "hcl", "provider", "module", "state", "tfstate",
        "plan", "apply", "destroy", "infrastructure as code", "iac",
        "resource", "data source", "variable", "output",
    ],
    "falco": [
        "falco", "falco rule", "falcosidekick", "runtime detection",
        "runtime security", "syscall", "system call", "ebpf", "kernel",
        "falco alert", "falco event", "runtime threat",
    ],
    "kyverno": [
        "kyverno", "kyverno policy", "admission policy", "cluster policy",
        "mutating", "validating", "generate", "policy enforcement",
        "policy report", "policy exception",
    ],
    "vault": [
        "vault", "hashicorp vault", "secret management", "secret engine",
        "transit", "pki", "kv", "dynamic secret", "seal", "unseal",
        "token", "approle", "oidc", "vault agent",
    ],
    "argocd": [
        "argocd", "argo cd", "gitops", "application", "applicationset",
        "sync", "sync policy", "app of apps", "progressive delivery",
        "argo rollout", "blue green", "canary deployment",
    ],
    "siem": [
        "siem", "wazuh", "opensearch", "elasticsearch", "log analysis",
        "security information", "event management", "log correlation",
        "alert rule", "detection rule", "sigma rule", "suricata",
    ],
    "soc": [
        "soc", "security operations", "analyst", "tier 1", "tier 2",
        "incident response", "playbook", "runbook", "escalation",
        "triage", "forensics", "investigation", "containment",
    ],
    "incidents": [
        "incident", "alert", "notification", "severity", "critical",
        "high", "medium", "low", "mttd", "mttr", "mean time",
        "on-call", "pagerduty", "opsgenie", "postmortem",
    ],
    "logs": [
        "log", "logging", "loki", "promtail", "fluentd", "fluentbit",
        "logstash", "structured logging", "log aggregation", "log parsing",
        "trace", "tracing", "span", "opentelemetry", "otel", "tempo",
    ],
    "cve": [
        "cve", "nvd", "cvss", "trivy", "grype", "vulnerability scan",
        "container scan", "image scan", "security scan", "advisory",
        "patch", "remediation", "cwe", "epss",
    ],
    "sbom": [
        "sbom", "software bill of materials", "syft", "cyclonedx",
        "spdx", "dependency", "supply chain", "component", "bom",
        "artifact", "provenance", "slsa", "in-toto", "sigstore", "cosign",
    ],
    "supply_chain": [
        "supply chain", "software supply chain", "dependency confusion",
        "typosquatting", "package", "npm", "pypi", "registry",
        "attestation", "signature", "verification", "sbom", "provenance",
    ],
    "prompt_injection": [
        "prompt injection", "prompt attack", "adversarial prompt",
        "jailbreak", "dan", "ignore previous", "system prompt",
        "bypass", "role play attack", "prompt override",
    ],
}

# Map categories to expert models
CATEGORY_MODEL_MAP: Dict[str, str] = {
    "cybersecurity": "CyberSecurityAgent",
    "devsecops": "CyberSecurityAgent",
    "kubernetes": "DevOpsAgent",
    "docker": "DevOpsAgent",
    "jenkins": "DevOpsAgent",
    "terraform": "DevOpsAgent",
    "falco": "CyberSecurityAgent",
    "kyverno": "CyberSecurityAgent",
    "vault": "CyberSecurityAgent",
    "argocd": "DevOpsAgent",
    "siem": "CyberSecurityAgent",
    "soc": "CyberSecurityAgent",
    "incidents": "CyberSecurityAgent",
    "logs": "DevOpsAgent",
    "cve": "CyberSecurityAgent",
    "sbom": "CyberSecurityAgent",
    "supply_chain": "CyberSecurityAgent",
    "prompt_injection": "CyberSecurityAgent",
}
