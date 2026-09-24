"""Localisation de vulnérabilité dans SECAI (antares-350m-like).

Ce module supporte :
- Chargement du modèle "fdtn-ai/antares-350m" (cas nominal MLOps).
- Fallback déprimatissant quand le modèle ne peut pas être télécharqué sur le
  cluster (CPU seule / pas de réseau) : correspondance par tokens et règles.

JAMAIS utilisé comme classificateur supervisé fine-tuning.
"""
from __future__ import annotations

import logging
import re
from typing import Any, Optional

import torch

from secai.config import get_settings
from secai.models.securebert_loader import SecureBERTLoader

logger = logging.getLogger("secai.models.antares")
settings = get_settings()

LOCALISATION_MODEL_ID = getattr(settings, "SECAI_LOCALISATION_MODEL_ID", "fdtn-ai/antares-350m")


class ModelUnavailable(RuntimeError):
    pass


class FallbackLocalizer:
    """Fallback dépoltiquez sur keywords + regex, jamais sans documents."""

    PATTERNS: dict[str, str] = {
        "sql_injection": r"select.*\{|exec|sqlite.*exec|query.*\$\{",
        "xss": r"<\s*script|innerHTML|document\.write|alert\(",
        "cmd_i": r"system\(|exec\(|shell_exec\(|subprocess\(",
        "file_inclusion": r"readfile|file_get_contents|include\(",
        "secret_in_code": r"[\'\"][A-Za-z0-9+/]{20,}[\'\"]",
    }

    def localize(self, code: str) -> dict:
        for cat, lex in self.PATTERNS.items():
            if re.search(lex, code, re.IGNORECASE | re.MULTILINE):
                loc = self._find_line_number(code, lex)
                return {
                    "category": cat,
                    "confidence": 0.75,
                    "method": "fallback-token-search",
                    "line_hint": loc,
                }
        return {"category": "unknown", "confidence": 0.0, "method": "none"}

    def _find_line_number(self, code: str, lex: str) -> Optional[int]:
        for i, line in enumerate(code.splitlines(), start=1):
            if re.search(lex, line, re.IGNORECASE):
                return i
        return None


class VulnerabilityLocalizer:
    """Séquentiellement application de fonctionget_remotelyparantee."""

    def __init__(self) -> None:
        self.tok = None
        self.model = None
        self.device = SecureBERTLoader.device() if SecureBERTLoader._model is not None else torch.device("cpu")
        self.loaded = False
        self._fallback = FallbackLocalizer()

    def load(self) -> None:
        if self.loaded:
            return
        if not LOCALISATION_MODEL_ID:
            raise ModelUnavailable("LOCALISATION_MODEL_ID missing")
        try:
            from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

            self.tok = AutoTokenizer.from_pretrained(LOCALISATION_MODEL_ID)
            self.model = AutoModelForSeq2SeqLM.from_pretrained(
                LOCALISATION_MODEL_ID, torch_dtype=torch.float32
            ).to(self.device)
            self.model.eval()
            self.loaded = True
            logger.info("SEC AI localisation model loaded: %s", LOCALISATION_MODEL_ID)
        except Exception as exc:
            self._fallback = FallbackLocalizer()
            logger.warning("SEC AI localisation fallback: %s", type(exc).__name__)

    def localize(self, code_snippet: str, cve_identifier: str | None = None) -> dict:
        """Retourne la localisation d'une vulnérabilité dans un snippet.

        Args:
            code_snippet — fragment de code (max ~800 caractères recommandés).
            cve_identifier — optionnel, pour logs.

        Returns: {
            "category": str,
            "confidence": float,
            "line_hint": int | None,
            "method": str,
            "model_id": str | None,
            "safe": True,
        }
        """
        if not self.loaded:
            self.load()
        if self.model is None:
            # fallback without network
            return self._fallback.localize(code_snippet)

        inputs = self.tok.encode(code_snippet, return_tensors="pt", max_length=1024, truncation=True).to(self.device)
        with torch.no_grad():
            out = self.model.generate(inputs, max_length=48)
        text = self.tok.decode(out[0], skip_special_tokens=True)
        return {
            "method": LOCALISATION_MODEL_ID,
            "category": text.strip()[:60] or "unknown",
            "confidence": 0.65,
            "line_hint": None,
            "model_id": LOCALISATION_MODEL_ID,
            "safe": True,
        }

    def is_loaded(self) -> bool:
        return self.loaded
