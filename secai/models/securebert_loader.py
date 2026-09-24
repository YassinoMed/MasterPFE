"""SECAI model loader — SecureBERT 2.0-base via HuggingFace Transformers.

IMPORTANT: this model is a classifier-free text encoder (MLM / feature extractor),
NOT a fine-tuned security classifier. We only use it for **embeddings** (mean pooling).
The "classification" of findings is rule-based — never pretend otherwise.

Logging policy: never log API keys, tokens, or prompt payloads.
"""
from __future__ import annotations

import hashlib
import logging
import os
import time
from typing import Optional

import torch
from transformers import AutoModel, AutoTokenizer

from secai.config import get_settings

logger = logging.getLogger("secai.models.securebert")
settings = get_settings()


class ModelNotAvailable(RuntimeError):
    """Raised when model files cannot be loaded (network/files missing)."""


class SecureBERTLoader:
    """
    Cached loader for `cisco-ai/SecureBERT2.0-base`.

    - Evaluates and crowds device (`cpu` unless `SECAI_DEVICE=cuda` present)
    - Enforces max_length via tokenizer `max_length` hint
    - Caches tokenizer + model, download controlled by `SECAI_MODEL_CACHE_DIR`
    - Inference runs under torch.inference_mode()
    """

    _tokenizer: Optional[AutoTokenizer] = None
    _model: Optional[AutoModel] = None
    _device: Optional[torch.device] = None
    _load_ts: Optional[float] = None

    @classmethod
    def device(cls) -> torch.device:
        if cls._device is None:
            if (
                settings.DEVICE == "cuda"
                or (settings.DEVICE == "auto" and torch.cuda.is_available())
            ):
                cls._device = torch.device("cuda")
            else:
                cls._device = torch.device("cpu")
            logger.info("secai: device=%s", cls._device.type)
        return cls._device

    @classmethod
    def load(cls) -> None:
        """Load tokenizer + model (idempotent)."""
        if cls._model is not None:
            return
        t0 = time.monotonic()

        model_id = settings.MODEL_ID
        if not model_id or "/" not in model_id:
            raise ModelNotAvailable("SECAI_MODEL_ID is invalid")

        cache_dir = settings.MODEL_CACHE_DIR
        os.makedirs(cache_dir, exist_ok=True)

        try:
            tok = AutoTokenizer.from_pretrained(model_id, cache_dir=cache_dir)
            model = AutoModel.from_pretrained(model_id, cache_dir=cache_dir)
        except (OSError, ValueError, RuntimeError) as exc:
            raise ModelNotAvailable(
                f"cannot load {model_id!r}: {type(exc).__name__}"
            ) from exc

        model.to(cls.device())
        model.eval()

        cls._tokenizer = tok
        cls._model = model
        cls._load_ts = t0
        logger.info("secai: model %s loaded in %.2fs (params=%sM)",
                    model_id, time.monotonic() - t0,
                    f"{sum(p.numel() for p in model.parameters()) / 1e6:.1f}")

    @classmethod
    def ensure_loaded(cls) -> None:
        if cls._model is None:
            cls.load()

    @classmethod
    def embed(cls, texts: list[str]) -> torch.Tensor:
        """
        Mean-pool over last hidden state (SecureBERT2.0 is an encoder).
        Returns a L2-normalized matrix of shape (n, hidden_size).
        """
        if not texts:
            return torch.empty((0, 0))
        cls.ensure_loaded()
        assert cls._tokenizer is not None and cls._model is not None

        # Bounded input length — never trust caller-controlled sizes
        truncated = [t[: settings.MAX_LENGTH * 4] for t in texts]
        inputs = cls._tokenizer(
            truncated,
            padding=True,
            truncation=True,
            max_length=settings.MAX_LENGTH,
            return_tensors="pt",
        )
        inputs = {k: v.to(cls.device()) for k, v in inputs.items()}
        with torch.inference_mode():
            outputs = cls._model(**inputs)
            last = outputs.last_hidden_state  # (batch, seq, hidden)
            mask = inputs["attention_mask"].unsqueeze(-1).expand(last.size()).float()
            masked = (last * mask).sum(axis=1) / mask.sum(axis=1).clamp(min=1e-9)
            normed = masked / masked.norm(dim=-1, keepdim=True).clamp(min=1e-9)
        return normed.cpu()
