"""SECAI settings — snapshot-free, environnement uniquement.

Aucune valeur sensible n'est chargée ici : secrets lus depuis infra/jenkins/secrets/
au démarrage de Jenkins ou contenus dans des k8s secrets (jamais codés).
"""
from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    # Modèle
    MODEL_ID: str = os.getenv("SECAI_MODEL_ID", "cisco-ai/SecureBERT2.0-base")
    # device : "auto" | "cpu" | "cuda"
    DEVICE: str = os.getenv("SECAI_DEVICE", "auto")
    MAX_LENGTH: int = int(os.getenv("SECAI_MAX_LENGTH", "1024"))
    # Scoring / décision
    CONFIDENCE_THRESHOLD: float = float(os.getenv("SECAI_CONFIDENCE_THRESHOLD", "0.80"))
    MODE: str = os.getenv("SECAI_MODE", "advisory")
    # Gates futurs (inactifs par défaut)
    ENABLE_EXTERNAL_LLM: bool = os.getenv("SECAI_ENABLE_EXTERNAL_LLM", "false").lower() == "true"
    AUTO_REMEDIATION: bool = os.getenv("SECAI_AUTO_REMEDIATION", "false").lower() == "true"
    # Cache des modèles (sans commit)
    MODEL_CACHE_DIR: str = os.getenv("SECAI_MODEL_CACHE_DIR", "/var/tmp/secai-model-cache")
    # Endpoint runtime futur (non actif en v0.1)
    LAYER_ENDPOINT: str = os.getenv("SECAI_LAYER_ENDPOINT", "")


_S = Settings()


def get_settings() -> Settings:
    return _S
