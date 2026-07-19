"""
Layer 4b — DevOps Expert Agent.

Uses kavinduc/devops-mastermind for DevOps and infrastructure expertise
including Jenkins, GitHub Actions, ArgoCD, Helm, Terraform, Ansible,
Docker, CI/CD, Kubernetes, and observability.
"""

import logging
import os
import time
from typing import Dict, Any, Optional

import torch

logger = logging.getLogger("ai-security-pipeline.devops-agent")

# ── DevOps System Prompt ───────────────────────────────────────
DEVOPS_SYSTEM_PROMPT = """You are DevOps Mastermind, an elite DevOps and Platform Engineering AI.
You specialise in enterprise-grade infrastructure, CI/CD, and cloud-native operations.

Your areas of expertise:
- CI/CD Pipelines (Jenkins, GitHub Actions, GitLab CI)
- GitOps (ArgoCD, Flux, progressive delivery)
- Container orchestration (Kubernetes, Helm, Kustomize)
- Infrastructure as Code (Terraform, Ansible, Pulumi)
- Container runtime (Docker, Buildkit, Kaniko)
- Observability (Prometheus, Grafana, Loki, Tempo, OpenTelemetry)
- Performance engineering (load testing, resource optimisation)
- Platform engineering (developer experience, internal platforms)
- Cloud infrastructure (AWS, GCP, Azure)
- Debugging and troubleshooting production systems

Rules:
- Provide specific, actionable configuration examples
- Reference best practices and official documentation
- Never execute commands directly — only advise
- Include YAML/HCL/Groovy examples where helpful
- Consider security implications in all recommendations
"""


class DevOpsAgent:
    """
    DevOps Expert Agent backed by the DevOps-Mastermind model.

    Falls back to structured heuristic responses when the model
    is unavailable (e.g., during CI/CD or limited hardware).
    """

    def __init__(
        self,
        model_name: str = "kavinduc/devops-mastermind",
        max_tokens: int = 256,
    ):
        self.model_name = model_name
        self.max_tokens = max_tokens
        self._model_loaded = False
        self.generator = None
        self.tokenizer = None
        self.model = None

        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        device_label = f"GPU ({torch.cuda.get_device_name(0)})" if self.device == "cuda" else "CPU"
        logger.info(
            "Initializing DevOpsAgent",
            extra={"model": model_name, "device": device_label},
        )

        self._load_model()

    def _load_model(self) -> None:
        """Load the HuggingFace causal-LM pipeline."""
        try:
            from transformers import (
                AutoTokenizer,
                AutoModelForCausalLM,
                pipeline as hf_pipeline,
            )

            logger.info("Loading DevOpsAgent tokenizer: %s", self.model_name)
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)

            logger.info("Loading DevOpsAgent model: %s", self.model_name)
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                device_map="auto" if self.device == "cuda" else None,
                low_cpu_mem_usage=True,
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
            )

            pipe_device = 0 if self.device == "cuda" else -1
            # Only set device if not using device_map="auto"
            pipe_kwargs = {
                "task": "text-generation",
                "model": self.model,
                "tokenizer": self.tokenizer,
            }
            if self.device != "cuda":
                pipe_kwargs["device"] = pipe_device

            self.generator = hf_pipeline(**pipe_kwargs)
            self._model_loaded = True
            logger.info("DevOpsAgent model loaded successfully")

        except Exception as exc:
            logger.error(
                "Failed to load DevOpsAgent: %s — running in fallback mode", exc
            )
            self.generator = None
            self._model_loaded = False

    # ── Public API ─────────────────────────────────────────────

    def generate_response(self, prompt: str) -> str:
        """
        Generate a DevOps expert response.

        Args:
            prompt: The user's query about DevOps/infrastructure topics.

        Returns:
            Expert analysis text.
        """
        if not self._model_loaded or self.generator is None:
            return self._fallback_response(prompt)

        try:
            formatted = (
                f"System: {DEVOPS_SYSTEM_PROMPT}\n\n"
                f"User: {prompt}\n\n"
                f"DevOps Expert:"
            )

            result = self.generator(
                formatted,
                max_new_tokens=self.max_tokens,
                num_return_sequences=1,
                do_sample=True,
                temperature=0.4,
                top_p=0.9,
                pad_token_id=self.tokenizer.eos_token_id,
            )

            generated_text = result[0]["generated_text"]
            # Extract only the generated response portion
            response = generated_text.split("DevOps Expert:")[-1].strip()

            if not response:
                return self._fallback_response(prompt)
            return response

        except Exception as exc:
            logger.error("DevOpsAgent inference error: %s", exc)
            return self._fallback_response(prompt)

    # ── MLOps ──────────────────────────────────────────────────

    def health_check(self) -> Dict[str, Any]:
        """Return model health status for readiness probes."""
        return {
            "model": self.model_name,
            "loaded": self._model_loaded,
            "device": self.device,
        }

    def warmup(self) -> None:
        """Run a short inference to warm the model."""
        if self._model_loaded:
            logger.info("Warming up DevOpsAgent...")
            self.generate_response("Explain a basic Jenkins pipeline stage.")
            logger.info("DevOpsAgent warmup complete")

    def get_memory_usage(self) -> Dict[str, float]:
        """Return approximate model memory usage."""
        import psutil
        process = psutil.Process(os.getpid())
        mem_info = process.memory_info()
        result = {
            "rss_mb": round(mem_info.rss / (1024**2), 1),
            "vms_mb": round(mem_info.vms / (1024**2), 1),
        }
        if torch.cuda.is_available():
            result["vram_allocated_mb"] = round(
                torch.cuda.memory_allocated() / (1024**2), 1
            )
            result["vram_reserved_mb"] = round(
                torch.cuda.memory_reserved() / (1024**2), 1
            )
        return result

    # ── Internal ───────────────────────────────────────────────

    def _fallback_response(self, prompt: str) -> str:
        """Structured heuristic response when model is unavailable."""
        prompt_lower = prompt.lower()

        if any(k in prompt_lower for k in ["jenkins", "jenkinsfile", "pipeline"]):
            return (
                "[DevOps Expert — Fallback Mode]\n\n"
                f"Regarding CI/CD pipeline:\n'{prompt}'\n\n"
                "Recommendations:\n"
                "1. Verify Jenkinsfile syntax with `declarative-linter`\n"
                "2. Check agent labels and node availability\n"
                "3. Review shared library versions\n"
                "4. Ensure credentials are properly scoped\n"
                "5. Add post { failure { } } blocks for error handling"
            )

        if any(k in prompt_lower for k in ["kubernetes", "k8s", "pod", "deployment"]):
            return (
                "[DevOps Expert — Fallback Mode]\n\n"
                f"Regarding Kubernetes:\n'{prompt}'\n\n"
                "Recommendations:\n"
                "1. Check pod status: `kubectl get pods -n <namespace>`\n"
                "2. Review events: `kubectl describe pod <pod>`\n"
                "3. Check logs: `kubectl logs <pod> --previous`\n"
                "4. Verify resource limits and requests\n"
                "5. Review HPA metrics and scaling policies"
            )

        if any(k in prompt_lower for k in ["helm", "chart", "values"]):
            return (
                "[DevOps Expert — Fallback Mode]\n\n"
                f"Regarding Helm:\n'{prompt}'\n\n"
                "Recommendations:\n"
                "1. Validate chart: `helm lint <chart>`\n"
                "2. Dry-run: `helm install --dry-run --debug`\n"
                "3. Check values override: `helm get values <release>`\n"
                "4. Review template rendering: `helm template <chart>`\n"
                "5. Verify chart dependencies: `helm dependency update`"
            )

        if any(k in prompt_lower for k in ["terraform", "hcl", "iac"]):
            return (
                "[DevOps Expert — Fallback Mode]\n\n"
                f"Regarding Terraform:\n'{prompt}'\n\n"
                "Recommendations:\n"
                "1. Run `terraform plan` to preview changes\n"
                "2. Validate syntax: `terraform validate`\n"
                "3. Format code: `terraform fmt -recursive`\n"
                "4. Check state: `terraform state list`\n"
                "5. Use workspaces for environment isolation"
            )

        if any(k in prompt_lower for k in ["argocd", "gitops", "sync"]):
            return (
                "[DevOps Expert — Fallback Mode]\n\n"
                f"Regarding ArgoCD/GitOps:\n'{prompt}'\n\n"
                "Recommendations:\n"
                "1. Check app health: `argocd app get <app>`\n"
                "2. Review sync status and diff\n"
                "3. Verify repo credentials and access\n"
                "4. Check ApplicationSet generators\n"
                "5. Review sync waves and hooks ordering"
            )

        return (
            "[DevOps Expert — Fallback Mode]\n\n"
            f"Analysis for: '{prompt}'\n\n"
            "Key DevOps recommendations:\n"
            "1. Review CI/CD pipeline configurations\n"
            "2. Check Kubernetes cluster health and resource usage\n"
            "3. Verify container image build and security scanning\n"
            "4. Review observability stack (Prometheus, Grafana, Loki)\n"
            "5. Ensure GitOps sync policies are correctly configured\n\n"
            "Note: Running in fallback mode. For full analysis, "
            "ensure the DevOps Mastermind model is available."
        )
