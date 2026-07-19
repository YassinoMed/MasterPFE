"""
Layer 2 — Jailbreak Detection.

Uses llm-semantic-router/mmbert32k-jailbreak-detector-merged to detect
jailbreak attempts including DAN, system prompt leakage, role play attacks,
and social engineering.

All prompts that pass Layer 1 must be validated here before routing.
"""

import logging
import re
import time
from typing import Dict, Any, List, Optional

import torch

logger = logging.getLogger("ai-security-pipeline.jailbreak")

# ── Known Jailbreak Patterns (Pre-screening) ──────────────────
# These patterns catch common jailbreak techniques before model inference,
# providing a fast-path rejection for obvious attacks.
JAILBREAK_PATTERNS: List[Dict[str, Any]] = [
    {
        "name": "DAN",
        "pattern": re.compile(
            r"(do anything now|DAN mode|DAN\s*\d|jailbroken|developer mode|"
            r"act as.*unrestricted|pretend.*no restrictions|ignore.*ethical)",
            re.IGNORECASE,
        ),
    },
    {
        "name": "IgnorePreviousInstructions",
        "pattern": re.compile(
            r"(ignore (all )?(previous|prior|above|system) (instructions?|prompts?|rules?|guidelines?)|"
            r"disregard (all )?(previous|prior|above|system)|"
            r"forget (all )?(previous|prior|your) (instructions?|rules?|programming))",
            re.IGNORECASE,
        ),
    },
    {
        "name": "SystemPromptLeakage",
        "pattern": re.compile(
            r"(show me your (system )?prompt|reveal your (system )?instructions?|"
            r"what (are|is) your (system )?prompt|"
            r"print your (system )?prompt|output your (initial|system) (prompt|instructions?)|"
            r"repeat (the words|everything) above)",
            re.IGNORECASE,
        ),
    },
    {
        "name": "RolePlayAttack",
        "pattern": re.compile(
            r"(you are now|from now on you are|act as|pretend (to be|you are)|"
            r"roleplay as|simulate being|you must act as|"
            r"respond as if you were|imagine you are|play the role of).*"
            r"(evil|malicious|hacker|unrestricted|unfiltered|uncensored|without limits)",
            re.IGNORECASE,
        ),
    },
    {
        "name": "PromptOverride",
        "pattern": re.compile(
            r"(override.*(safety|security|content|ethical)|"
            r"bypass.*(filter|restriction|safeguard|guardrail)|"
            r"disable.*(safety|security|content|ethical)|"
            r"turn off.*(safety|security|content))",
            re.IGNORECASE,
        ),
    },
    {
        "name": "SocialEngineering",
        "pattern": re.compile(
            r"(if you don.?t (help|answer|comply)|"
            r"this is.*(life|death|emergency|urgent)|"
            r"my (boss|manager|ceo|teacher).*|"
            r"I have permission to|I am authorized to|"
            r"for (educational|research|academic|testing) purposes only)",
            re.IGNORECASE,
        ),
    },
]


class JailbreakDetector:
    """
    Production-grade Jailbreak Detector combining pattern pre-screening
    with mmBERT32k model inference.

    Classification output:
        - allow:  Prompt is benign
        - review: Borderline / low confidence — needs human review
        - deny:   Jailbreak detected — prompt must be rejected
    """

    def __init__(
        self,
        model_name: str = "llm-semantic-router/mmbert32k-jailbreak-detector-merged",
        max_length: int = 512,
        review_threshold: float = 0.5,
        deny_threshold: float = 0.8,
    ):
        self.model_name = model_name
        self.max_length = max_length
        self.review_threshold = review_threshold
        self.deny_threshold = deny_threshold
        self._model_loaded = False
        self.classifier = None

        self.device = 0 if torch.cuda.is_available() else -1
        device_label = "GPU (cuda:0)" if self.device == 0 else "CPU"
        logger.info(
            "Initializing JailbreakDetector",
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
            logger.info("JailbreakDetector model loaded successfully")
        except Exception as exc:
            logger.error("Failed to load JailbreakDetector: %s", exc)
            self.classifier = None
            self._model_loaded = False

    # ── Public API ─────────────────────────────────────────────

    def detect(self, prompt: str) -> Dict[str, Any]:
        """
        Analyse a prompt for jailbreak attempts.

        Returns:
            dict with keys:
                classification: "allow" | "review" | "deny"
                confidence: float 0-1
                original_label: raw model label
                attack_types: list of detected pattern names
                inference_time_ms: float
        """
        start = time.perf_counter()

        # Phase 1: Pattern pre-screening (fast path)
        matched_patterns = self._pattern_scan(prompt)
        if matched_patterns:
            elapsed_ms = (time.perf_counter() - start) * 1000
            logger.warning(
                "Jailbreak patterns detected: %s", matched_patterns
            )
            return {
                "classification": "deny",
                "confidence": 0.99,
                "original_label": "PATTERN_MATCH",
                "attack_types": matched_patterns,
                "inference_time_ms": round(elapsed_ms, 2),
            }

        # Phase 2: Model inference
        if not self._model_loaded or self.classifier is None:
            logger.warning("Model not loaded — failing closed with 'review'")
            return {
                "classification": "review",
                "confidence": 0.0,
                "original_label": "MODEL_UNAVAILABLE",
                "attack_types": [],
                "inference_time_ms": 0.0,
            }

        result = self.classifier(prompt)[0]
        elapsed_ms = (time.perf_counter() - start) * 1000

        label = str(result["label"]).upper()
        score = float(result["score"])

        classification = self._classify(label, score)

        return {
            "classification": classification,
            "confidence": round(score, 4),
            "original_label": label,
            "attack_types": [],
            "inference_time_ms": round(elapsed_ms, 2),
        }

    def predict(self, prompt: str) -> str:
        """Convenience: returns only the classification string."""
        return self.detect(prompt)["classification"]

    def score(self, prompt: str) -> float:
        """Convenience: returns only the confidence score."""
        return self.detect(prompt)["confidence"]

    def is_denied(self, prompt: str) -> bool:
        """Quick boolean check for blocking logic."""
        return self.predict(prompt) == "deny"

    # ── MLOps ──────────────────────────────────────────────────

    def health_check(self) -> Dict[str, Any]:
        """Return model health status for readiness probes."""
        return {
            "model": self.model_name,
            "loaded": self._model_loaded,
            "device": "cuda" if self.device == 0 else "cpu",
            "pattern_rules": len(JAILBREAK_PATTERNS),
        }

    def warmup(self) -> None:
        """Run a dummy prediction to warm JIT caches."""
        if self._model_loaded:
            logger.info("Warming up JailbreakDetector...")
            self.detect("This is a normal user question about Kubernetes security.")
            logger.info("JailbreakDetector warmup complete")

    # ── Internal ───────────────────────────────────────────────

    def _pattern_scan(self, prompt: str) -> List[str]:
        """Run regex-based pre-screening against known jailbreak patterns."""
        matched = []
        for entry in JAILBREAK_PATTERNS:
            if entry["pattern"].search(prompt):
                matched.append(entry["name"])
        return matched

    def _classify(self, label: str, score: float) -> str:
        """
        Map raw model output to our tri-state classification.

        The mmbert32k-jailbreak-detector typically returns:
            JAILBREAK — prompt is adversarial
            BENIGN    — prompt is safe
        """
        if label in ("JAILBREAK", "MALICIOUS", "LABEL_1"):
            if score >= self.deny_threshold:
                return "deny"
            return "review"

        if label in ("BENIGN", "SAFE", "LABEL_0"):
            if score >= self.deny_threshold:
                return "allow"
            if score >= self.review_threshold:
                return "allow"
            # Low-confidence benign → review
            return "review"

        # Unknown label fallback
        logger.warning("Unexpected label '%s' from jailbreak model", str(label))
        return "review"
