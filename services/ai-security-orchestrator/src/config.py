"""AI Security Orchestrator — Configuration."""
import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings from environment variables."""
    VERSION: str = "1.0.0"
    ENVIRONMENT: str = os.getenv("APP_ENV", "development")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")

    # External service URLs
    PROMETHEUS_URL: str = os.getenv("PROMETHEUS_URL", "http://prometheus.securerag-monitoring.svc:9090")
    LOKI_URL: str = os.getenv("LOKI_URL", "http://loki.securerag-monitoring.svc:3100")
    FALCO_URL: str = os.getenv("FALCO_URL", "http://falco.falco.svc:8765")
    VAULT_URL: str = os.getenv("VAULT_URL", "http://securerag-vault.vault.svc:8200")
    ARGOCD_URL: str = os.getenv("ARGOCD_URL", "http://argocd-server.argocd.svc:443")
    HARBOR_URL: str = os.getenv("HARBOR_URL", "https://harbor.securerag.local")

    # AI engine thresholds
    RISK_THRESHOLD_BLOCK: float = float(os.getenv("RISK_THRESHOLD_BLOCK", "75.0"))
    RISK_THRESHOLD_WARN: float = float(os.getenv("RISK_THRESHOLD_WARN", "50.0"))
    CONSENSUS_MIN_AGENTS: int = int(os.getenv("CONSENSUS_MIN_AGENTS", "3"))
    CONSENSUS_QUORUM: float = float(os.getenv("CONSENSUS_QUORUM", "0.7"))

    # Rollback settings
    ROLLBACK_ENABLED: bool = os.getenv("ROLLBACK_ENABLED", "true").lower() == "true"
    ROLLBACK_COOLDOWN_SECONDS: int = int(os.getenv("ROLLBACK_COOLDOWN_SECONDS", "300"))

    class Config:
        env_prefix = "ORCHESTRATOR_"


settings = Settings()
