import os
import re
import time
import logging
from typing import Dict, Any
from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai-inference")

app = FastAPI(
    title="AI Security Inference Service",
    description="Inference service deploying 'omasteam/cyberguard-ai-security-analyzer' with heuristic fallback.",
    version="0.1.0"
)

@app.on_event("startup")
def on_startup():
    from prometheus_fastapi_instrumentator import Instrumentator
    Instrumentator().instrument(app).expose(app)
    logger.info("Prometheus instrumentation initialized for Inference Service.")

# Configuration flags
MOCK_INFERENCE = os.getenv("MOCK_INFERENCE", "true").lower() in ("true", "1", "yes")
MODEL_ID = "omasteam/cyberguard-ai-security-analyzer"

tokenizer = None
model = None
model_loaded = False

# Attempt to load Hugging Face model if mock mode is disabled
if not MOCK_INFERENCE:
    try:
        logger.info(f"Attempting to load model: {MODEL_ID}...")
        from transformers import AutoTokenizer, AutoModelForCausalLM
        import torch

        # Use CPU if GPU is unavailable, specify low memory usage
        device = "cuda" if torch.cuda.is_available() else "cpu"
        logger.info(f"Using device: {device}")

        tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
        # Load in 8-bit or with low_cpu_mem_usage to save memory
        model = AutoModelForCausalLM.from_pretrained(
            MODEL_ID,
            torch_dtype=torch.float16 if device == "cuda" else torch.float32,
            device_map="auto" if device == "cuda" else None,
            low_cpu_mem_usage=True
        )
        model_loaded = True
        logger.info("Model loaded successfully.")
    except Exception as e:
        logger.error(f"Failed to load model {MODEL_ID}: {e}. Falling back to heuristic mode.")
        model_loaded = False
else:
    logger.info("MOCK_INFERENCE is active. Running in heuristic fallback mode.")


class AnalysisRequest(BaseModel):
    source: str = Field(..., example="Tetragon")
    log: str = Field(..., example="process exec /bin/sh")


class AnalysisResponse(BaseModel):
    classification: str = Field(..., example="MALICIOUS")
    confidence: float = Field(..., example=96.0)
    severity: str = Field(..., example="CRITICAL")
    explanation: str = Field(..., example="Reverse shell detected")
    recommendation: str = Field(..., example="Isolate container and rotate secrets")


def heuristic_analyze(source: str, log: str) -> Dict[str, Any]:
    """
    A high-fidelity rule-based heuristic security scanner that mimics the Llama model
    by identifying known malicious/suspicious signatures in DevSecOps log sources.
    """
    log_lower = log.lower()
    source_lower = source.lower()

    # 1. Tetragon / Runtime system call events
    if "tetragon" in source_lower or "process" in log_lower or "sys_call" in log_lower:
        if any(x in log_lower for x in ["/bin/sh", "/bin/bash", "nc -e", "/bin/zsh", "reverse", "bash -i"]):
            return {
                "classification": "MALICIOUS",
                "confidence": 98.0,
                "severity": "CRITICAL",
                "explanation": "Interactive shell execution detected within runtime environment.",
                "recommendation": "Isolate the pod immediately, kill the active pid, and check for container escape attempts."
            }
        if any(x in log_lower for x in ["chmod +x", "chown root", "sys_ptrace", "cap_sys_admin"]):
            return {
                "classification": "SUSPICIOUS",
                "confidence": 85.0,
                "severity": "HIGH",
                "explanation": "Privilege escalation activity or executable privilege modification detected.",
                "recommendation": "Review the Pod Security Standards and restrict runtime capabilities."
            }

    # 2. Falco alerts
    if "falco" in source_lower or "alert" in log_lower:
        if "sensitive file" in log_lower or "read sensitive" in log_lower or "/etc/shadow" in log_lower:
            return {
                "classification": "MALICIOUS",
                "confidence": 95.0,
                "severity": "HIGH",
                "explanation": "Unauthorized read attempt of sensitive system files.",
                "recommendation": "Inspect container privileges, enable read-only root filesystems, and rotate system credentials."
            }
        if "write below binary" in log_lower or "modify binary" in log_lower:
            return {
                "classification": "MALICIOUS",
                "confidence": 92.0,
                "severity": "CRITICAL",
                "explanation": "Write operation detected below a system binary directory.",
                "recommendation": "Lock down root filesystem, rebuild from trusted image, and inspect post-compromise hooks."
            }

    # 3. Wazuh / SSH / Access failures
    if "wazuh" in source_lower or "siem" in source_lower or "auth" in log_lower:
        if "failed password" in log_lower or "login failed" in log_lower:
            # Check for potential brute force
            matches = re.findall(r"failed", log_lower)
            if len(matches) > 3 or "brute" in log_lower:
                return {
                    "classification": "MALICIOUS",
                    "confidence": 90.0,
                    "severity": "HIGH",
                    "explanation": "Possible SSH or API access brute-force attack detected.",
                    "recommendation": "Temporarily block the origin IP using network policy / iptables, and enforce MFA."
                }
            return {
                "classification": "SUSPICIOUS",
                "confidence": 75.0,
                "severity": "MEDIUM",
                "explanation": "Single failed login attempt detected.",
                "recommendation": "Monitor user login pattern and verify credential integrity."
            }
        if "accepted password" in log_lower or "successful login" in log_lower:
            if "root" in log_lower:
                return {
                    "classification": "SUSPICIOUS",
                    "confidence": 80.0,
                    "severity": "MEDIUM",
                    "explanation": "Root user login detected via public endpoint.",
                    "recommendation": "Disable root access via SSH, enforce key-based authentication only."
                }

    # 4. K8s events
    if "kube" in source_lower or "k8s" in source_lower:
        if "unauthorized" in log_lower or "forbidden" in log_lower:
            return {
                "classification": "SUSPICIOUS",
                "confidence": 88.0,
                "severity": "HIGH",
                "explanation": "K8s API client failed RBAC authorization checks.",
                "recommendation": "Verify ServiceAccount permissions, check for leaked tokens, and enforce network isolation."
            }
        if "oomkilled" in log_lower or "backoff" in log_lower:
            return {
                "classification": "SUSPICIOUS",
                "confidence": 70.0,
                "severity": "MEDIUM",
                "explanation": "Pod container crashed or got OOMKilled.",
                "recommendation": "Check application memory profile and increase resource limits if coherent."
            }

    # 5. Generic network / Istio traffic anomalies
    if "istio" in source_lower or "network" in log_lower:
        if "sql injection" in log_lower or "union select" in log_lower or "select * from" in log_lower:
            return {
                "classification": "MALICIOUS",
                "confidence": 97.0,
                "severity": "CRITICAL",
                "explanation": "SQL Injection payload detected in ingress network request.",
                "recommendation": "Enable WAF blocking rules, check input parameter binding, and audit backend database queries."
            }
        if "path traversal" in log_lower or "../" in log_lower:
            return {
                "classification": "MALICIOUS",
                "confidence": 94.0,
                "severity": "HIGH",
                "explanation": "Directory traversal payload detected in HTTP request path.",
                "recommendation": "Sanitize URL path parameters and verify webserver document root boundaries."
            }

    # 6. Default fallback for normal logs
    return {
        "classification": "NORMAL",
        "confidence": 99.0,
        "severity": "LOW",
        "explanation": "Log analysis reveals normal system behavior without threats.",
        "recommendation": "No action required. Continue routine log collection and threat monitoring."
    }


@app.post("/analyze", response_model=AnalysisResponse)
def analyze(payload: AnalysisRequest):
    start_time = time.time()
    try:
        # If model is loaded, run LLM inference (Llama-2 format prompt)
        if model_loaded and tokenizer is not None and model is not None:
            prompt = f"### System: Analyze the following log from {payload.source} and categorize it as NORMAL, SUSPICIOUS, or MALICIOUS. Provide classification, confidence score (0-100), severity (LOW, MEDIUM, HIGH, CRITICAL), explanation, and recommendation.\n\n### Log: {payload.log}\n\n### Analysis:"
            inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
            outputs = model.generate(**inputs, max_new_tokens=150, temperature=0.1)
            response_text = tokenizer.decode(outputs[0], skip_special_tokens=True)

            # Extract generated text after prompt
            analysis_text = response_text.replace(prompt, "").strip()

            # Parse expected structure from the generated text
            classification = "NORMAL"
            confidence = 90.0
            severity = "LOW"
            explanation = "Automated LLM analysis completed."
            recommendation = "Check logs."

            if "MALICIOUS" in analysis_text.upper():
                classification = "MALICIOUS"
                severity = "HIGH"
            elif "SUSPICIOUS" in analysis_text.upper():
                classification = "SUSPICIOUS"
                severity = "MEDIUM"

            # Parse confidence if present (e.g., Confidence: 95%)
            conf_match = re.search(r"(\d+)%", analysis_text)
            if conf_match:
                confidence = float(conf_match.group(1))

            # Parse explanation
            lines = [l.strip() for l in analysis_text.split("\n") if l.strip()]
            for line in lines:
                if line.upper().startswith("EXPLANATION:"):
                    explanation = line[12:].strip()
                elif line.upper().startswith("RECOMMENDATION:"):
                    recommendation = line[15:].strip()

            return AnalysisResponse(
                classification=classification,
                confidence=confidence,
                severity=severity,
                explanation=explanation,
                recommendation=recommendation
            )

        # Heuristic fallback (production-ready and lightweight)
        res = heuristic_analyze(payload.source, payload.log)
        logger.info(f"Analyzed log from {payload.source} in {time.time() - start_time:.4f}s via Heuristic Engine.")
        return AnalysisResponse(
            classification=res["classification"],
            confidence=res["confidence"],
            severity=res["severity"],
            explanation=res["explanation"],
            recommendation=res["recommendation"]
        )

    except Exception as e:
        logger.error(f"Inference exception: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": model_loaded,
        "mode": "huggingface" if model_loaded else "heuristics_fallback"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
