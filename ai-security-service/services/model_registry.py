"""
MLOps Model Registry.

Central registry for all AI models in the security pipeline.
Handles versioning, health tracking, warmup orchestration,
GPU detection, CPU fallback, and resource monitoring.
"""

import logging
import os
import time
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field
from datetime import datetime, timezone

import psutil

logger = logging.getLogger("ai-security-pipeline.model-registry")


@dataclass
class ModelEntry:
    """Metadata for a registered model."""
    name: str
    version: str
    model_type: str  # "classifier", "generator", "gguf"
    source: str      # HuggingFace repo or file path
    loaded: bool = False
    load_time_ms: float = 0.0
    last_inference: Optional[str] = None
    inference_count: int = 0
    error_count: int = 0
    device: str = "cpu"
    memory_mb: float = 0.0


class ModelRegistry:
    """
    Central model registry and lifecycle manager.

    Coordinates all model loading, health checks, warmups,
    and resource monitoring for the AI security pipeline.
    """

    def __init__(self):
        self._models: Dict[str, ModelEntry] = {}
        self._instances: Dict[str, Any] = {}
        self._gpu_available = False
        self._gpu_name = "N/A"
        self._gpu_vram_gb = 0.0

        self._detect_gpu()

    def _detect_gpu(self) -> None:
        """Detect GPU availability and capabilities."""
        try:
            import torch
            if torch.cuda.is_available():
                self._gpu_available = True
                self._gpu_name = torch.cuda.get_device_name(0)
                self._gpu_vram_gb = torch.cuda.get_device_properties(0).total_mem / (1024**3)
                logger.info(
                    "GPU detected: %s (%.1f GB VRAM)",
                    self._gpu_name,
                    self._gpu_vram_gb,
                )
            else:
                logger.info("No GPU detected — all models will use CPU")
        except ImportError:
            logger.info("PyTorch not available for GPU detection")

    # ── Registration ───────────────────────────────────────────

    def register(
        self,
        name: str,
        instance: Any,
        version: str = "1.0.0",
        model_type: str = "classifier",
        source: str = "",
    ) -> None:
        """Register a model instance with the registry."""
        entry = ModelEntry(
            name=name,
            version=version,
            model_type=model_type,
            source=source,
        )

        # Check if instance has health_check method
        if hasattr(instance, "health_check"):
            health = instance.health_check()
            entry.loaded = health.get("loaded", False)
            entry.device = health.get("device", "cpu")

        self._models[name] = entry
        self._instances[name] = instance

        logger.info(
            "Registered model: %s (v%s, type=%s, loaded=%s)",
            name, version, model_type, entry.loaded,
        )

    # ── Health ─────────────────────────────────────────────────

    def health_check(self) -> Dict[str, Any]:
        """Return health status of all registered models."""
        models_health = {}
        for name, entry in self._models.items():
            instance = self._instances.get(name)
            if instance and hasattr(instance, "health_check"):
                models_health[name] = instance.health_check()
            else:
                models_health[name] = {
                    "loaded": entry.loaded,
                    "device": entry.device,
                }

        all_loaded = all(m.get("loaded", False) for m in models_health.values())

        return {
            "status": "healthy" if all_loaded else "degraded",
            "gpu_available": self._gpu_available,
            "gpu_name": self._gpu_name,
            "gpu_vram_gb": round(self._gpu_vram_gb, 1),
            "models": models_health,
            "total_models": len(self._models),
            "loaded_models": sum(1 for m in models_health.values() if m.get("loaded")),
        }

    # ── Warmup ─────────────────────────────────────────────────

    def warmup_all(self) -> Dict[str, float]:
        """
        Run warmup on all registered models.

        Returns:
            dict mapping model name → warmup time in ms
        """
        warmup_times = {}
        for name, instance in self._instances.items():
            if hasattr(instance, "warmup"):
                start = time.perf_counter()
                try:
                    instance.warmup()
                    elapsed_ms = (time.perf_counter() - start) * 1000
                    warmup_times[name] = round(elapsed_ms, 1)
                    self._models[name].load_time_ms = elapsed_ms
                    logger.info("Warmup %s: %.1f ms", name, elapsed_ms)
                except Exception as exc:
                    logger.error("Warmup failed for %s: %s", name, exc)
                    warmup_times[name] = -1.0
        return warmup_times

    # ── Resource Monitoring ────────────────────────────────────

    def get_resource_usage(self) -> Dict[str, Any]:
        """Return current resource usage across all models."""
        process = psutil.Process(os.getpid())
        mem_info = process.memory_info()

        result = {
            "process_rss_mb": round(mem_info.rss / (1024**2), 1),
            "process_vms_mb": round(mem_info.vms / (1024**2), 1),
            "cpu_percent": process.cpu_percent(interval=0.1),
            "system_memory_percent": psutil.virtual_memory().percent,
        }

        if self._gpu_available:
            try:
                import torch
                result["gpu_vram_allocated_mb"] = round(
                    torch.cuda.memory_allocated() / (1024**2), 1
                )
                result["gpu_vram_reserved_mb"] = round(
                    torch.cuda.memory_reserved() / (1024**2), 1
                )
                result["gpu_utilization_percent"] = "N/A"  # Requires nvidia-smi
            except Exception:
                pass

        # Per-model memory (where available)
        model_memory = {}
        for name, instance in self._instances.items():
            if hasattr(instance, "get_memory_usage"):
                try:
                    model_memory[name] = instance.get_memory_usage()
                except Exception:
                    pass
        result["model_memory"] = model_memory

        return result

    # ── Versioning ─────────────────────────────────────────────

    def get_versions(self) -> Dict[str, str]:
        """Return version information for all registered models."""
        return {
            name: {
                "version": entry.version,
                "source": entry.source,
                "model_type": entry.model_type,
            }
            for name, entry in self._models.items()
        }

    # ── Statistics ─────────────────────────────────────────────

    def record_inference(self, model_name: str) -> None:
        """Record a successful inference."""
        if model_name in self._models:
            self._models[model_name].inference_count += 1
            self._models[model_name].last_inference = (
                datetime.now(timezone.utc).isoformat()
            )

    def record_error(self, model_name: str) -> None:
        """Record an inference error."""
        if model_name in self._models:
            self._models[model_name].error_count += 1

    def get_statistics(self) -> Dict[str, Any]:
        """Return inference statistics for all models."""
        return {
            name: {
                "inference_count": entry.inference_count,
                "error_count": entry.error_count,
                "last_inference": entry.last_inference,
                "error_rate": (
                    round(entry.error_count / max(entry.inference_count, 1), 4)
                ),
            }
            for name, entry in self._models.items()
        }
