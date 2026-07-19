"""
Shared test fixtures and mock model factories for AI Security Service tests.

All tests use mock models to avoid downloading actual HuggingFace weights,
enabling fast CI/CD execution.
"""

import os
import sys
import pytest
from unittest.mock import MagicMock, patch

# Ensure the project root is on the path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Mock heavy ML dependencies before importing models
class MockTensor:
    pass

mock_torch = MagicMock()
mock_torch.Tensor = MockTensor
sys.modules["torch"] = mock_torch

sys.modules["transformers"] = MagicMock()
sys.modules["llama_cpp"] = MagicMock()

import models.prompt_injection
import models.jailbreak_detector
import models.cybersecurity_agent
import models.devops_agent


# ── Mock Fixtures ──────────────────────────────────────────────

@pytest.fixture
def mock_pi_detector():
    """Mock PromptInjectionDetector that doesn't load real models."""
    with patch("models.prompt_injection.PromptInjectionDetector._load_model"):
        from models.prompt_injection import PromptInjectionDetector
        detector = PromptInjectionDetector.__new__(PromptInjectionDetector)
        detector.model_name = "protectai/deberta-v3-small-prompt-injection-v2"
        detector.max_length = 512
        detector.suspicious_threshold = 0.5
        detector.malicious_threshold = 0.8
        detector._model_loaded = True
        detector.device = -1

        # Mock classifier pipeline
        detector.classifier = MagicMock()
        yield detector


@pytest.fixture
def mock_jb_detector():
    """Mock JailbreakDetector that doesn't load real models."""
    with patch("models.jailbreak_detector.JailbreakDetector._load_model"):
        from models.jailbreak_detector import JailbreakDetector
        detector = JailbreakDetector.__new__(JailbreakDetector)
        detector.model_name = "llm-semantic-router/mmbert32k-jailbreak-detector-merged"
        detector.max_length = 512
        detector.review_threshold = 0.5
        detector.deny_threshold = 0.8
        detector._model_loaded = True
        detector.device = -1
        detector.classifier = MagicMock()
        yield detector


@pytest.fixture
def mock_cyber_agent():
    """Mock CyberSecurityAgent in fallback mode."""
    with patch("models.cybersecurity_agent.CyberSecurityAgent._load_model"), \
         patch("models.cybersecurity_agent.CyberSecurityAgent._detect_gpu"):
        from models.cybersecurity_agent import CyberSecurityAgent
        agent = CyberSecurityAgent.__new__(CyberSecurityAgent)
        agent.model_path = "/app/models/test.gguf"
        agent.n_ctx = 2048
        agent.max_tokens = 512
        agent.n_threads = 4
        agent.n_gpu_layers = 0
        agent.llm = None
        agent._model_loaded = False  # Fallback mode
        yield agent


@pytest.fixture
def mock_devops_agent():
    """Mock DevOpsAgent in fallback mode."""
    with patch("models.devops_agent.DevOpsAgent._load_model"):
        from models.devops_agent import DevOpsAgent
        agent = DevOpsAgent.__new__(DevOpsAgent)
        agent.model_name = "kavinduc/devops-mastermind"
        agent.max_tokens = 256
        agent.device = "cpu"
        agent._model_loaded = False  # Fallback mode
        agent.generator = None
        agent.tokenizer = None
        agent.model = None
        yield agent


@pytest.fixture
def semantic_router():
    """Real SemanticRouter instance (no model downloads needed)."""
    from routing.semantic_router import SemanticRouter
    return SemanticRouter()
