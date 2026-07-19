"""
Layer 1 — Prompt Injection Detection.

Uses protectai/deberta-v3-small-prompt-injection-v2 for classifying prompts
as safe, suspicious, or malicious. All user queries must pass through this
layer before reaching any LLM.

Model outputs: INJECTION or SAFE with confidence scores.
"""

import logging
import time
from typing import Dict, Any, Optional

import torch

logger = logging.getLogger("ai-security-pipeline.prompt-injection")


class PromptInjectionDetector:
    """
    Production-grade Prompt Injection Detector using DeBERTa-v3.

    Classification output:
        - safe:       Prompt is benign (SAFE label, high confidence)
        - suspicious: Low-confidence result, needs human review
        - malicious:  Prompt injection detected (INJECTION label)
    """

    def __init__(
        self,
        model_name: str = "protectai/deberta-v3-small-prompt-injection-v2",
        max_length: int = 512,
        suspicious_threshold: float = 0.5,
        malicious_threshold: float = 0.8,
    ):
        self.model_name = model_name
        self.max_length = max_length
        self.suspicious_threshold = suspicious_threshold
        self.malicious_threshold = malicious_threshold
        self._model_loaded = False
        self.classifier = None

        # Detect GPU availability
        self.device = 0 if torch.cuda.is_available() else -1
        device_label = "GPU (cuda:0)" if self.device == 0 else "CPU"
        logger.info(
            "Initializing PromptInjectionDetector",
            extra={"model": model_name, "device": device_label},
        )

        self._load_model()

    def _load_model(self) -> None:
        """Load the HuggingFace text-classification pipeline."""
        try:
            from transformers import pipeline as hf_pipeline

            self.classifier = hf_pipeline(
                "text-classification",
                model=self.model_name,
                device=self.device,
                truncation=True,
                max_length=self.max_length,
            )
            self._model_loaded = True
            logger.info("PromptInjectionDetector model loaded successfully")
        except Exception as exc:
            logger.error("Failed to load PromptInjectionDetector: %s", exc)
            self.classifier = None
            self._model_loaded = False

    # ── Public API ─────────────────────────────────────────────

    def detect(self, prompt: str) -> Dict[str, Any]:
        """
        Analyse a prompt for injection attempts.

        Returns:
            dict with keys:
                classification: "safe" | "suspicious" | "malicious"
                confidence: float 0-1
                original_label: raw model label
                inference_time_ms: float
        """
        if not self._model_loaded or self.classifier is None:
            logger.warning("Model not loaded — failing open with 'suspicious'")
            return {
                "classification": "suspicious",
                "confidence": 0.0,
                "original_label": "MODEL_UNAVAILABLE",
                "inference_time_ms": 0.0,
            }

        start = time.perf_counter()
        result = self.classifier(prompt)[0]
        elapsed_ms = (time.perf_counter() - start) * 1000

        label = result["label"].upper()
        score = result["score"]

        classification = self._classify(label, score)

        return {
            "classification": classification,
            "confidence": round(score, 4),
            "original_label": label,
            "inference_time_ms": round(elapsed_ms, 2),
        }

    def predict(self, prompt: str) -> str:
        """Convenience: returns only the classification string."""
        return self.detect(prompt)["classification"]

    def score(self, prompt: str) -> float:
        """Convenience: returns only the confidence score."""
        return self.detect(prompt)["confidence"]

    def is_malicious(self, prompt: str) -> bool:
        """Quick boolean check for blocking logic."""
        return self.predict(prompt) == "malicious"

    # ── MLOps ──────────────────────────────────────────────────

    def health_check(self) -> Dict[str, Any]:
        """Return model health status for readiness probes."""
        return {
            "model": self.model_name,
            "loaded": self._model_loaded,
            "device": "cuda" if self.device == 0 else "cpu",
        }

    def warmup(self) -> None:
        """Run a dummy prediction to warm JIT caches."""
        if self._model_loaded:
            logger.info("Warming up PromptInjectionDetector...")
            self.detect("This is a warmup prompt for model initialisation.")
            logger.info("PromptInjectionDetector warmup complete")

    # ── Internal ───────────────────────────────────────────────

    def _classify(self, label: str, score: float) -> str:
        """
        Map raw model output to our tri-state classification.

        The protectai/deberta-v3-small-prompt-injection-v2 model returns:
            INJECTION  — prompt is adversarial
            SAFE       — prompt is benign
        """
        if label == "INJECTION":
            if score >= self.malicious_threshold:
                return "malicious"
            return "suspicious"

        if label == "SAFE":
            if score >= self.malicious_threshold:
                return "safe"
            if score >= self.suspicious_threshold:
                return "safe"
            # Low-confidence SAFE is suspicious
            return "suspicious"

        # Unknown label fallback
        logger.warning("Unexpected label '%s' from model", label)
        return "suspicious" if score < self.malicious_threshold else "malicious"
