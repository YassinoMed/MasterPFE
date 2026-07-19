"""
Layer 4a — CyberSecurity Expert Agent.

Uses AlicanKiraz0/Seneca-Cybersecurity-LLM-Q4_K_M-GGUF via llama-cpp-python
for deep cybersecurity analysis including CVE, MITRE ATT&CK, Trivy, Grype,
SBOM, Falco, Tetragon, Sigma, YARA, Suricata, and Supply Chain.
"""

import logging
import os
import time
from typing import Dict, Any, Optional

logger = logging.getLogger("ai-security-pipeline.cybersecurity-agent")

# ── Domain-specific System Prompts ─────────────────────────────
CYBERSECURITY_SYSTEM_PROMPT = """You are Seneca, an elite Cybersecurity Expert AI.
You specialise in enterprise-grade security analysis for DevSecOps environments.

Your areas of expertise:
- CVE Analysis and CVSS scoring
- MITRE ATT&CK Framework mapping (Tactics, Techniques, Procedures)
- Container security (Trivy, Grype, image scanning)
- SBOM analysis (CycloneDX, SPDX, Syft)
- Runtime security (Falco, Tetragon, eBPF)
- Detection engineering (Sigma rules, YARA rules, Suricata rules)
- Kubernetes security (RBAC, NetworkPolicies, PodSecurity)
- Docker security (Dockerfile best practices, image hardening)
- Linux security (kernel hardening, SELinux, AppArmor)
- Software Supply Chain security (SLSA, Sigstore, attestations)

Rules:
- Always provide actionable, specific recommendations
- Reference relevant frameworks (MITRE ATT&CK, NIST, CIS Benchmarks)
- Never execute commands directly — only advise
- Include severity ratings when applicable
- Cite CVE IDs, CWE IDs where relevant
"""


class CyberSecurityAgent:
    """
    CyberSecurity Expert Agent backed by Seneca GGUF model.

    Falls back to a structured heuristic response when the GGUF model
    is not available (e.g., during CI/CD or when running on limited hardware).
    """

    def __init__(
        self,
        model_path: str = "/app/models/seneca-cybersecurity-llm-q4_k_m.gguf",
        n_ctx: int = 2048,
        max_tokens: int = 512,
        n_threads: int = 4,
        n_gpu_layers: int = 0,
    ):
        self.model_path = model_path
        self.n_ctx = n_ctx
        self.max_tokens = max_tokens
        self.n_threads = n_threads
        self.n_gpu_layers = n_gpu_layers
        self.llm = None
        self._model_loaded = False

        self._detect_gpu()
        self._load_model()

    def _detect_gpu(self) -> None:
        """Auto-detect GPU and adjust gpu_layers accordingly."""
        try:
            import torch
            if torch.cuda.is_available():
                gpu_name = torch.cuda.get_device_name(0)
                vram_gb = torch.cuda.get_device_properties(0).total_mem / (1024**3)
                logger.info(
                    "GPU detected: %s (%.1f GB VRAM)", gpu_name, vram_gb
                )
                # Auto-assign GPU layers if not explicitly set
                if self.n_gpu_layers == 0 and vram_gb >= 4.0:
                    self.n_gpu_layers = 35  # Offload most layers to GPU
                    logger.info("Auto-configured %d GPU layers", self.n_gpu_layers)
            else:
                logger.info("No GPU detected — running on CPU")
        except ImportError:
            logger.info("torch not available for GPU detection — CPU mode")

    def _load_model(self) -> None:
        """Load the GGUF model via llama-cpp-python."""
        if not os.path.exists(self.model_path):
            logger.warning(
                "Model file not found at %s — operating in fallback mode",
                self.model_path,
            )
            return

        try:
            from llama_cpp import Llama

            logger.info("Loading CyberSecurityAgent from %s", self.model_path)
            self.llm = Llama(
                model_path=self.model_path,
                n_ctx=self.n_ctx,
                n_threads=self.n_threads,
                n_gpu_layers=self.n_gpu_layers,
                verbose=False,
            )
            self._model_loaded = True
            logger.info("CyberSecurityAgent model loaded successfully")
        except Exception as exc:
            logger.error("Failed to load CyberSecurityAgent: %s", exc)
            self.llm = None
            self._model_loaded = False

    # ── Public API ─────────────────────────────────────────────

    def generate_response(self, prompt: str) -> str:
        """
        Generate a cybersecurity analysis response.

        Args:
            prompt: The user's query about cybersecurity topics.

        Returns:
            Expert analysis text.
        """
        if not self._model_loaded or self.llm is None:
            return self._fallback_response(prompt)

        try:
            formatted = (
                f"{CYBERSECURITY_SYSTEM_PROMPT}\n\n"
                f"User Query: {prompt}\n\n"
                f"Expert Analysis:"
            )

            output = self.llm(
                formatted,
                max_tokens=self.max_tokens,
                stop=["User Query:", "User:", "\n\n\n"],
                echo=False,
                temperature=0.3,
                top_p=0.9,
            )

            response = output["choices"][0]["text"].strip()
            if not response:
                return self._fallback_response(prompt)
            return response

        except Exception as exc:
            logger.error("CyberSecurityAgent inference error: %s", exc)
            return self._fallback_response(prompt)

    # ── MLOps ──────────────────────────────────────────────────

    def health_check(self) -> Dict[str, Any]:
        """Return model health status for readiness probes."""
        return {
            "model": "Seneca-Cybersecurity-LLM-Q4_K_M",
            "model_path": self.model_path,
            "loaded": self._model_loaded,
            "gpu_layers": self.n_gpu_layers,
            "ctx_size": self.n_ctx,
        }

    def warmup(self) -> None:
        """Run a short inference to warm the model."""
        if self._model_loaded:
            logger.info("Warming up CyberSecurityAgent...")
            self.generate_response("Summarise MITRE ATT&CK Tactic TA0001.")
            logger.info("CyberSecurityAgent warmup complete")

    def get_memory_usage(self) -> Dict[str, float]:
        """Return approximate model memory usage."""
        import psutil
        process = psutil.Process(os.getpid())
        mem_info = process.memory_info()
        result = {
            "rss_mb": round(mem_info.rss / (1024**2), 1),
            "vms_mb": round(mem_info.vms / (1024**2), 1),
        }
        try:
            import torch
            if torch.cuda.is_available():
                result["vram_allocated_mb"] = round(
                    torch.cuda.memory_allocated() / (1024**2), 1
                )
                result["vram_reserved_mb"] = round(
                    torch.cuda.memory_reserved() / (1024**2), 1
                )
        except ImportError:
            pass
        return result

    # ── Internal ───────────────────────────────────────────────

    def _fallback_response(self, prompt: str) -> str:
        """
        Structured heuristic response when the GGUF model is unavailable.
        Provides useful guidance even without the model.
        """
        prompt_lower = prompt.lower()

        if "cve" in prompt_lower:
            return (
                "[CyberSecurity Expert — Fallback Mode]\n\n"
                f"Regarding your query about CVE analysis:\n"
                f"'{prompt}'\n\n"
                "Recommendations:\n"
                "1. Run `trivy image <image>` to scan for known CVEs\n"
                "2. Check NVD (nvd.nist.gov) for CVSS scores and vectors\n"
                "3. Cross-reference with EPSS for exploitability probability\n"
                "4. Apply patches from vendor advisories\n"
                "5. Use Kyverno policies to block images with CRITICAL CVEs"
            )

        if any(k in prompt_lower for k in ["falco", "runtime", "ebpf", "tetragon"]):
            return (
                "[CyberSecurity Expert — Fallback Mode]\n\n"
                f"Regarding runtime security:\n"
                f"'{prompt}'\n\n"
                "Recommendations:\n"
                "1. Review Falco rules in /etc/falco/falco_rules.yaml\n"
                "2. Check Falcosidekick for alert routing configuration\n"
                "3. Correlate with Tetragon eBPF policies for syscall monitoring\n"
                "4. Verify Kubernetes audit logging is enabled\n"
                "5. Map findings to MITRE ATT&CK for threat context"
            )

        if any(k in prompt_lower for k in ["sbom", "supply chain", "sigstore", "cosign"]):
            return (
                "[CyberSecurity Expert — Fallback Mode]\n\n"
                f"Regarding supply chain security:\n"
                f"'{prompt}'\n\n"
                "Recommendations:\n"
                "1. Generate SBOM with `syft <image> -o cyclonedx-json`\n"
                "2. Sign images with `cosign sign --key <key> <image>`\n"
                "3. Verify attestations with `cosign verify-attestation`\n"
                "4. Implement SLSA Level 3 provenance\n"
                "5. Use Kyverno to enforce image signature verification"
            )

        return (
            "[CyberSecurity Expert — Fallback Mode]\n\n"
            f"Analysis for: '{prompt}'\n\n"
            "This query requires deep cybersecurity analysis. "
            "Key actions:\n"
            "1. Review relevant SIEM alerts and Falco logs\n"
            "2. Check Trivy/Grype scan results for vulnerabilities\n"
            "3. Verify RBAC and NetworkPolicy configurations\n"
            "4. Map findings to MITRE ATT&CK framework\n"
            "5. Consult CIS Kubernetes Benchmark recommendations\n\n"
            "Note: Running in fallback mode. For full analysis, "
            "ensure the Seneca GGUF model is available."
        )
