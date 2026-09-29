"""Log-to-Dataset Transformer — Transforme les logs sécurité en datasets
d'entraînement pour modèles AISEC via Qwen2.5-0.5B.

Pipeline :
  1. LIT les logs bruts (Falco JSON, Trivy JSON, Kyverno reports)
  2. EXTRAIT les features pertinentes (règle, sévérité, processus, fichier…)
  3. GÉNÈRE des paires (instruction, réponse) via Ollama
  4. APPLIQUE les guardrails (injection detection, output filtering)
  5. EXPORT en format JSONL (fine-tuning ready) + Qdrant (RAG)

Types de datasets générés :
  - "classification" : log → catégorie d'attaque (MITRE, CWE)
  - "severity"       : log → niveau de sévérité (CRITICAL/HIGH/MEDIUM/LOW)
  - "remediation"    : log → action corrective recommandée
  - "explanation"    : log → explication en langage naturel

Intégration guardrails :
  - scan_prompt_injection : si le log contient une injection → BLOCK
  - scan_output          : si la réponse LLM contient un secret → neutralisée
  - canary_tokens        : si le prompt système fuit → IR-404
"""
from __future__ import annotations

import json
import os
import time
import urllib.request
from dataclasses import dataclass
from enum import Enum
from pathlib import Path


class DatasetType(str, Enum):
    CLASSIFICATION = "classification"
    SEVERITY = "severity"
    REMEDIATION = "remediation"
    EXPLANATION = "explanation"


@dataclass(frozen=True)
class TrainingExample:
    """Une paire d'entraînement au format JSONL (fine-tuning ready)."""

    instruction: str      # le log d'entrée (question posée au modèle)
    response: str         # la réponse attendue (générée par Qwen)
    dataset_type: str     # classification/severity/remediation/explanation
    source: str           # falco/trivy/kyverno/audit
    severity: str        # CRITICAL/HIGH/MEDIUM/LOW
    rule: str            # règle détectée
    mitre_tags: list[str]  # tags MITRE ATT&CK
    guardrail_verdict: str  # ALLOW/BLOCK/SANITIZE
    created_at: str


# ── Extraction des features depuis les logs bruts ───────────────────────────

def extract_falco_features(event: dict) -> dict:
    """Extrait les features pertinentes d'un event Falco JSON."""
    fields = event.get("output_fields", {})
    return {
        "rule": event.get("rule", ""),
        "priority": event.get("priority", ""),
        "process": fields.get("proc.name", ""),
        "command": fields.get("proc.cmdline", ""),
        "file": fields.get("fd.name", ""),
        "user": fields.get("user.name", ""),
        "container": fields.get("container.name", ""),
        "tags": event.get("tags", []),
        "output_text": event.get("output", "")[:500],  # tronqué pour le prompt
    }


def extract_trivy_features(finding: dict) -> dict:
    """Extrait les features d'un finding Trivy."""
    return {
        "rule": finding.get("VulnerabilityID", finding.get("ID", "")),
        "priority": finding.get("Severity", "MEDIUM"),
        "process": finding.get("PkgName", ""),
        "command": "",
        "file": finding.get("FilePath", ""),
        "user": "",
        "container": "",
        "tags": finding.get("References", [])[:3],
        "output_text": finding.get("Description", finding.get("Message", ""))[:500],
    }


# ── Génération via Ollama (Qwen2.5-0.5B) ────────────────────────────────────

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11499")
MODEL = os.getenv("TRANSFORM_MODEL", "qwen2.5-0.5b")

# Prompts pour chaque type de dataset (version 0.5B optimisée)
PROMPTS = {
    DatasetType.CLASSIFICATION: (
        "Classify this security event into a MITRE ATT&CK tactic. "
        "Respond with ONLY the tactic name (e.g., Credential Access, Persistence, Execution).\n\n"
        "Event: {event_text}\n"
        "Rule: {rule}\n"
        "Process: {process} {command}\n"
    ),
    DatasetType.SEVERITY: (
        "Rate the severity of this security event from 1 to 5.\n"
        "5=Critical (data breach, RCE), 4=High (privilege escalation), "
        "3=Medium (suspicious activity), 2=Low (informational), 1=None.\n"
        "Respond with ONLY the number.\n\n"
        "Event: {event_text}\n"
        "Rule: {rule}\n"
    ),
    DatasetType.REMEDIATION: (
        "What is the recommended remediation for this security event?\n"
        "Respond in ONE sentence starting with 'Remediation:'\n\n"
        "Event: {event_text}\n"
        "Rule: {rule}\n"
        "Severity: {priority}\n"
    ),
    DatasetType.EXPLANATION: (
        "Explain this security event in simple terms for a security analyst.\n"
        "Respond in 2-3 sentences.\n\n"
        "Event: {event_text}\n"
        "Rule: {rule}\n"
    ),
}


def _call_ollama(prompt: str) -> str:
    """Appelle Ollama pour générer une réponse (déterministe)."""
    body = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.1,
            "seed": 42,
            "num_predict": 150,  # limité pour la vitesse
        },
    }).encode()

    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        d = json.loads(r.read())
    return d.get("response", "").strip()


def _apply_guardrails(log_text: str, llm_response: str) -> tuple[str, str]:
    """Applique les guardrails au log d'entrée ET à la réponse LLM.

    Returns:
        (response_cleaned, guardrail_verdict)
    """
    from secai.guardrails.injection import scan_prompt_injection
    from secai.guardrails.output_filter import scan_output, Verdict

    # 1. Guardrail IN : le log contient-il une injection ?
    input_scan = scan_prompt_injection(log_text)
    if input_scan.verdict == Verdict.BLOCK:
        return ("[BLOCKED: log contient une injection]", "BLOCK")

    # 2. Guardrail OUT : la réponse contient-elle un secret ?
    output_scan = scan_output(llm_response)
    if output_scan.verdict == Verdict.BLOCK:
        return ("[NEUTRALIZED: secret détecté dans la réponse]", "SANITIZE")

    return (output_scan.cleaned, "ALLOW")


# ── Transformation principale ─────────────────────────────────────────────────

def transform_log_to_dataset(
    log_event: dict,
    source: str = "falco",
    dataset_types: list[DatasetType] | None = None,
) -> list[TrainingExample]:
    """Transforme UN log en plusieurs exemples d'entraînement.

    Pour chaque type de dataset demandé, génère une paire (instruction, réponse)
    via Qwen2.5-0.5B et applique les guardrails.
    """
    if dataset_types is None:
        dataset_types = [DatasetType.CLASSIFICATION, DatasetType.SEVERITY, DatasetType.REMEDIATION]

    # Extraire les features
    if source == "falco":
        features = extract_falco_features(log_event)
    elif source == "trivy":
        features = extract_trivy_features(log_event)
    else:
        features = extract_falco_features(log_event)  # fallback

    # Les MITRE tags sont déjà dans les logs Falco
    mitre_tags = [t for t in features.get("tags", []) if t.startswith(("T1", "TA", "PCI"))]

    examples = []
    for ds_type in dataset_types:
        prompt_template = PROMPTS.get(ds_type)
        if not prompt_template:
            continue

        # Construire le prompt
        prompt = prompt_template.format(
            event_text=features["output_text"],
            rule=features["rule"],
            process=features["process"],
            command=features["command"],
            priority=features["priority"],
        )

        # Générer via Ollama
        try:
            llm_response = _call_ollama(prompt)
        except Exception:
            llm_response = f"[FALLBACK] {features['rule']} - {features['priority']}"

        # Appliquer les guardrails
        cleaned_response, verdict = _apply_guardrails(
            features["output_text"], llm_response
        )

        example = TrainingExample(
            instruction=features["output_text"],
            response=cleaned_response,
            dataset_type=ds_type.value,
            source=source,
            severity=features["priority"],
            rule=features["rule"],
            mitre_tags=mitre_tags,
            guardrail_verdict=verdict,
            created_at=time.strftime("%Y-%m-%dT%H:%M:%S"),
        )
        examples.append(example)

    return examples


# ── Export ────────────────────────────────────────────────────────────────────

def export_jsonl(examples: list[TrainingExample], output_path: str) -> int:
    """Export en format JSONL (compatible fine-tuning LoRA/QLoRA)."""
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for ex in examples:
            f.write(json.dumps({
                "instruction": ex.instruction,
                "response": ex.response,
                "metadata": {
                    "type": ex.dataset_type,
                    "source": ex.source,
                    "severity": ex.severity,
                    "rule": ex.rule,
                    "mitre_tags": ex.mitre_tags,
                    "guardrail_verdict": ex.guardrail_verdict,
                    "created_at": ex.created_at,
                },
            }) + "\n")
    return len(examples)


def export_summary(examples: list[TrainingExample]) -> dict:
    """Résumé statistique du dataset généré."""
    by_type = {}
    by_severity = {}
    by_verdict = {}
    for ex in examples:
        by_type[ex.dataset_type] = by_type.get(ex.dataset_type, 0) + 1
        by_severity[ex.severity] = by_severity.get(ex.severity, 0) + 1
        by_verdict[ex.guardrail_verdict] = by_verdict.get(ex.guardrail_verdict, 0) + 1

    return {
        "total_examples": len(examples),
        "by_dataset_type": by_type,
        "by_severity": by_severity,
        "by_guardrail_verdict": by_verdict,
        "sources": list(set(ex.source for ex in examples)),
        "mitre_tags_covered": sorted(set(t for ex in examples for t in ex.mitre_tags)),
    }
