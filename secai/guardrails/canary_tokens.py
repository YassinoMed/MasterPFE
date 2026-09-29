"""Canary Tokens — Détection de prompt extraction par tokens leurrés (LLM07).

Technique inspirée des canary tokens de sécurité réseau/web : on insère
des tokens UNIQUES et SECRETS dans le system prompt. Si ces tokens
apparaissent dans la sortie du modèle, quelqu'un a extrait le prompt.

Workflow :
  1. GÉNÉRER : créer un set de canary tokens uniques et injectables
     dans le system prompt
  2. DÉTECTER : scanner les SORTIES du LLM pour détecter la présence
     de ces tokens
  3. ALERTER : si un canary est détecté dans une sortie, c'est une
     extraction de prompt → IR-404 immédiat

Types de canary tokens :
  - UUID v4 : "sk-canary-a1b2c3d4-e5f6-..."
  - Hex : "XJ4K9PZ" (courts, difficiles à deviner)
  - Naturels : phrases codées uniques

Le principe : ces tokens n'ont AUCUNE raison d'apparaître dans une
réponse légitime. S'ils apparaissent, le prompt a fuité.
"""
from __future__ import annotations

import hashlib
import os
import re
import secrets
import time
from dataclasses import dataclass, field
from enum import Enum


class CanaryType(str, Enum):
    UUID = "uuid"           # sk-canary-<uuid4>
    HEX = "hex"             # sk-canary-<8 hex chars>
    PHRASE = "phrase"       # phrase unique codée


@dataclass(frozen=True)
class CanaryToken:
    """Un token leurré injecté dans le system prompt."""

    token: str            # le token complet (ex: "sk-canary-abc123def")
    token_type: CanaryType
    created_at: str       # timestamp ISO
    description: str      # où il est placé (system_prompt, context…)


@dataclass(frozen=True)
class CanaryDetection:
    """Résultat du scan d'une sortie LLM pour des canary tokens."""

    detected: bool
    matched_tokens: list[str]    # les canaries trouvés dans la sortie
    source_text: str             # extrait de la sortie (preuve)
    timestamp: str


# ── Génération de canary tokens ──────────────────────────────────────────────

def generate_canary_token(token_type: CanaryType = CanaryType.HEX) -> CanaryToken:
    """Génère un canary token unique et difficile à deviner."""
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")

    if token_type == CanaryType.UUID:
        import uuid
        token = f"sk-canary-{uuid.uuid4()}"
        desc = "UUID v4 — injecté dans le system prompt"

    elif token_type == CanaryType.HEX:
        hex_part = secrets.token_hex(8)
        token = f"sk-canary-{hex_part}"
        desc = "Hex 16 chars — injecté dans le system prompt"

    elif token_type == CanaryType.PHRASE:
        # Phrases uniques générées aléatoirement
        words = ["aurora", "quartz", "nimbus", "vertex", "cipher", "zephyr", "onyx"]
        num = secrets.randbelow(999999)
        word = secrets.choice(words)
        token = f"sk-canary-{word}-{num:06d}"
        desc = "Phrase codée unique — injectée dans le contexte"

    return CanaryToken(
        token=token,
        token_type=token_type,
        created_at=timestamp,
        description=desc,
    )


def generate_canary_set(n: int = 5) -> list[CanaryToken]:
    """Génère un set de N canary tokens (mélange de types)."""
    types = [CanaryType.UUID, CanaryType.HEX, CanaryType.HEX, CanaryType.PHRASE, CanaryType.HEX]
    return [generate_canary_token(types[i % len(types)]) for i in range(n)]


# ── Injection dans le system prompt ──────────────────────────────────────────

def inject_canaries_in_prompt(system_prompt: str, canaries: list[CanaryToken]) -> str:
    """Injecte les canary tokens dans un system prompt.

    Les tokens sont placés à des positions stratégiques :
      - Au début (si quelqu'un fait "print system prompt")
      - Au milieu (si quelqu'un extrait partiellement)
      - À la fin (si quelqu'un fait "show last instructions")

    Ils ressemblent à des clés API pour attirer l'attention d'un attaquant.
    """
    lines = [system_prompt, ""]

    # Insérer les canary tokens comme de fausses clés API
    lines.append("# API Keys (do not share)")
    for i, canary in enumerate(canaries):
        lines.append(f"# Key {i+1}: {canary.token}")

    lines.append("")
    return "\n".join(lines)


# ── Détection dans les sorties ──────────────────────────────────────────────

def detect_canaries_in_output(
    output: str,
    canaries: list[CanaryToken],
    fuzzy: bool = True,
) -> CanaryDetection:
    """Scanne une sortie LLM pour détecter la présence de canary tokens.

    Deux modes :
      - Exact : le token complet apparaît dans la sortie
      - Fuzzy : des PARTIES du token apparaissent (mêmes si masquées
        partiellement, ex: "sk-canary-abc1..." ou "...c123def")

    Si un canary est détecté → le prompt a fuité → IR-404.

    Args:
        output: la sortie du LLM à scanner
        canaries: les canary tokens à chercher
        fuzzy: si True, détecte aussi les fragments partiels
    """
    matched = []

    for canary in canaries:
        # 1. Détection exacte
        if canary.token in output:
            matched.append(canary.token)
            continue

        # 2. Détection fuzzy : fragments de >= 12 chars
        if fuzzy and len(canary.token) >= 12:
            # Vérifier si une portion significative du token est présente
            # (au moins 12 caractères consécutifs)
            for i in range(len(canary.token) - 11):
                fragment = canary.token[i:i+12]
                if fragment in output:
                    matched.append(f"{canary.token} (fragment: {fragment})")
                    break

    detected = len(matched) > 0

    # Extraire un échantillon de la sortie comme preuve (jamès le token complet)
    if detected:
        # Trouver la première occurrence
        for m in matched:
            idx = output.find(m.split(" (")[0])  # retirer le suffixe fuzzy
            if idx >= 0:
                start = max(0, idx - 20)
                end = min(len(output), idx + len(m.split(" (")[0]) + 20)
                source = output[start:end]
                # MASQUER le token dans la preuve (ne pas le re-leaker)
                source = source.replace(m.split(" (")[0], "[CANARY-DETECTED]")
                break
        else:
            source = "(token détecté via fragment)"
    else:
        source = ""

    return CanaryDetection(
        detected=detected,
        matched_tokens=matched,
        source_text=source[:200],  # limiter la taille de la preuve
        timestamp=time.strftime("%Y-%m-%dT%H:%M:%S"),
    )


# ── Intégration avec le guardrail existant (GI-02) ──────────────────────────

def canary_guardrail_envelope(
    output: str,
    canaries: list[CanaryToken],
) -> dict:
    """Enveloppe pour l'API : détecte les canary tokens dans la sortie.

    À appeler APRÈS scan_output (LLM02) et scan_prompt_injection (LLM01).
    """
    detection = detect_canaries_in_output(output, canaries)

    return {
        "canary_check": {
            "detected": detection.detected,
            "incident": "PROMPT_EXTRACTION" if detection.detected else None,
            "matched_count": len(detection.matched_tokens),
            "evidence": detection.source_text,  # token MASQUÉ dans la preuve
            "timestamp": detection.timestamp,
        },
        "requires_human_review": detection.detected,
        "ir_playbook": "IR-404 (prompt extraction/jailbreak)" if detection.detected else None,
    }
